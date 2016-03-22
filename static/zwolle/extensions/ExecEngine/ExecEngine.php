<?php
// Define hooks
$hook1 = array('class' => 'ExecEngine', 'function' => 'run', 'filename' => 'ExecEngine.php', 'filepath' => 'extensions/ExecEngine', 'params' => array());
Hooks::addHook('preDatabaseCloseTransaction', $hook1);
$hook2 = array('class' => 'ExecEngine', 'function' => 'run', 'filename' => 'ExecEngine.php', 'filepath' => 'extensions/ExecEngine', 'params' => array(true));
Hooks::addHook('postDatabaseReinstallDB', $hook2);

// UI
$GLOBALS['navBar']['refreshMenu'][] = array ( 'url' =>	'extensions/ExecEngine/ui/views/MenuItem.html');
AngularApp::addJS('extensions/ExecEngine/ui/js/ExecEngine.js');

// Config (can be overwritten in localSettings.php)
Config::set('execEngineRoleName', 'execEngine', 'ExecEngine');
Config::set('autoRerun', 'execEngine', true);
Config::set('maxRunCount', 'execEngine', 10);

class ExecEngine {
	
	private static $roleName;
	public static $doRun = true;
	public static $autoRerun;
	public static $runCount;
	
	public static function run($allRules = false){
		$database = Database::singleton();
		
		Notifications::addLog('------------------------- EXEC ENGINE STARTED -------------------------', 'ExecEngine');
		
		// Load the execEngine functions (security hazard :P)
		$files = getDirectoryList(__DIR__ . '/functions');
		foreach ($files as $file){
			if (substr($file,-3) !== 'php') continue;
			require_once __DIR__.'/functions/'.$file;
			Notifications::addLog('Included file: '.__DIR__ .'/functions/'.$file, 'ExecEngine');
		}
		
		self::$roleName = Config::get('execEngineRoleName', 'execEngine');
		try{
		    $role = Role::getRoleByName(self::$roleName);
		}catch (Exception $e){
		    Notifications::addInfo("ExecEngine extension included but role '" . self::$roleName . "' not found.");
		    self::$doRun = false; // prevent exec engine execution
		}
		
		$maxRunCount = Config::get('maxRunCount', 'execEngine');
		self::$runCount = 0;
		self::$autoRerun = Config::get('autoRerun', 'execEngine');
		
		// Get all rules that are maintained by the ExecEngine
		while(self::$doRun){
			self::$doRun = false;
			self::$runCount++;

			// Prevent infinite loop in ExecEngine reruns 				
			if(self::$runCount > $maxRunCount){
				Notifications::addError('Maximum reruns exceeded for ExecEngine (rules with violations:' . implode(', ', (array)$rulesThatHaveViolations). ')');
				break;
			}
			
			Notifications::addLog("ExecEngine run #" . self::$runCount . " (auto rerun: " . var_export(self::$autoRerun, true) . ") for role '" . $role->label . "'", 'ExecEngine');
			
			// Determine affected rules that must be checked by the exec engine
			$affectedConjuncts = RuleEngine::getAffectedConjuncts($database->getAffectedConcepts(), $database->getAffectedRelations(), 'sig');
			
			$affectedRules = array();
			foreach($affectedConjuncts as $conjunct) $affectedRules = array_merge($affectedRules, $conjunct->sigRuleNames);
			
			// Check rules
			$rulesThatHaveViolations = array();
			foreach ($role->maintains() as $ruleName){
				if(!in_array($ruleName, $affectedRules) && !$allRules) continue; // skip this rule
				
				$rule = Rule::getRule($ruleName);
				$violations = $rule->getViolations(false);
				
				if(count($violations)){
					$rulesThatHaveViolations[] = $rule->id;
					
					// Fix violations for every rule
					Notifications::addLog("ExecEngine fixing violations for rule '{$rule->id}'", 'ExecEngine');
					ExecEngine::fixViolations($violations); // Conjunct violations are not cached, because they are fixed by the ExecEngine
					Notifications::addInfo("{self::$roleName} fixed violations for rule '{$rule->id}", "ExecEngineSuccessMessage", "{self::$roleName} automatically fixed violations");
					
					// If $autoRerun, set $doRun to true because violations have been fixed (this may fire other execEngine rules)
					if(self::$autoRerun) self::$doRun = true;
				}
			}	
		}
		
		Notifications::addLog('------------------------- END OF EXEC ENGINE -------------------------', 'ExecEngine');	
	}
	
	/**
	 * 
	 * @param Violation[] $violations
	 * @throws Exception
	 * @return void
	 */
	public static function fixViolations($violations){
		
		foreach ($violations as $violation){
		    $violation = new ExecEngineViolation($violation->rule, $violation->src->id, $violation->tgt->id);
		    
			$theMessage = $violation->getViolationMessage();
			
			// Determine actions/functions to be taken
			$functionsToBeCalled = explode('{EX}', $theMessage);
			
			// Execute actions/functions
			foreach ($functionsToBeCalled as $functionToBeCalled) {
				if(empty($functionToBeCalled)) continue; // skips to the next iteration if $functionToBeCalled is empty. This is the case when violation text starts with delimiter {EX}
				
				// Determine delimiter
				if(substr($functionToBeCalled, 0, 2) == '_;'){
					$delimiter = '_;';
					$functionToBeCalled = substr($functionToBeCalled, 2);
				}else{
					$delimiter = ';';
				}
				
				$params = explode($delimiter, $functionToBeCalled); // Split off variables
				$params = array_map('trim', $params); // Trim all params
				$params = array_map('phpArgumentInterpreter', $params); // Evaluate phpArguments, using phpArgumentInterpreter function
				
				$function = array_shift($params); // First parameter is function name
				$classMethod = (array)explode('::', $function);
				
				if (function_exists($function) || method_exists($classMethod[0], $classMethod[1])){
					$successMessage = call_user_func_array($function,$params);
					Notifications::addLog($successMessage, 'ExecEngine');
					
				}else{
					throw new Exception("Function '{$function}' does not exists. Create function with {count($params)} parameters", 500);
				}
			}
		}		
	}
}

class ExecEngineViolation extends Violation {
	
	/**
	 * Overwrites getViolationMessage() method from Violation class
	 * @throws Exception when segment type is unknown
	 * @throws Exception when segment expression return more that 1 tgt atom
	 * @return string
	 */
	public function getViolationMessage(){
	    $database = Database::singleton();
	
	    $strArr = array();
	    foreach ($this->rule->violationSegments as $segment){
	        // text segment
	        if ($segment['segmentType'] == 'Text'){
	            $strArr[] = $segment['Text'];
	             
	        // expressie segment
	        }elseif($segment['segmentType'] == 'Exp'){
	            // select starting atom depending on whether the segment uses the src of tgt atom.
	            $atom = $segment['srcOrTgt'] == 'Src' ? $this->src : $this->tgt;
	
	            // quering the expression
	            $query = "SELECT DISTINCT `tgt` FROM ($segment[expSQL]) AS `results` WHERE `src` = '{$atom->idEsc}'"; // SRC of TGT kunnen door een expressie gevolgd worden
	            $rows = $database->Exe($query);
	
	            // returning the result
				if(count($rows) == 0){
				    $strArr[] = '_NULL';
				}else{
				    $str = '';
					foreach ($rows as $row) $str .= $row['tgt'] . '_AND';
					$str = substr($str, 0, -4); // strip the last _AND
					$strArr[] = str_replace(array('{EX}','{php}'), '', $str); // prevent php interpreter by user input. Only allowed as Text segments specified in &-script
				}
	
	        // unknown segment
	        }else{
	            $errorMessage = "Unknown segmentType '{$segment['segmentType']}' in violationSegments of rule '{$this->rule->id}'";
	            throw new Exception($errorMessage, 501); // 501: Not implemented
	        }
	    }
	
	    return $this->message = implode($strArr);
	}
}

?>