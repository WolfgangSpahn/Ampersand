<?php

class ObjectInterface {
	
	public $id;
	public $name; // TODO: kan vervallen?
	public $label;
	
	public $interfaceRoles = array();
	
	public $invariantConjuctsIds;
	public $signalConjunctsIds;
	
	public $relation; 
	public $relationIsFlipped;
	public $univalent;
	public $totaal;
	public $editable;
	
	public $srcConcept;
	public $tgtConcept;
	public $tgtDataType;
	
	public $refInterface;
	private $boxSubInterfaces;
	public $subInterfaces = array();
	
	public $expressionSQL;

	/*
	 * $refInterfacesArr is used to determine infinite loops in refInterface
	 */
	public function __construct($name, $interface = array(), $refInterfacesArr = array()){
		global $allInterfaceObjects; // from Generics.php
		
		if(empty($interface)) $interface = $allInterfaceObjects[$name]; // if no $interface is provided, use toplevel interfaces from $allInterfaceObjects
		
		// Check if interface exists
		if(empty($interface['name'])) throw new Exception ("Interface \'$name\' does not exists", 500);
		
		// Set attributes of interface
		$this->id = $interface['name'];
		$this->name = $interface['name'];
		$this->label = $interface['name'];
		$this->interfaceRoles = $interface['interfaceRoles'];
		
		$this->invariantConjuctsIds = $interface['invConjunctIds']; // only applicable for Top-level interfaces
		$this->signalConjunctsIds = $interface['sigConjunctIds']; // only applicable for Top-level interfaces
		
		$this->editableConcepts = $interface['editableConcepts']; // used by genEditableConceptInfo() function in AmpersandViewer.php
		$this->interfaceInvariantConjunctNames = $interface['interfaceInvariantConjunctNames']; // only applies to top level interface
		
		// Information about the (editable) relation if applicable
		$this->relation = $interface['relation']; 
		$this->relationIsFlipped = $interface['relationIsFlipped'];
		$this->editable = (empty($interface['relation'])) ? false : $interface['relationIsEditable'];
		$this->totaal = $interface['exprIsTot'];
		$this->univalent = $interface['exprIsUni'];
		$this->srcConcept = $interface['srcConcept'];
		$this->tgtConcept = $interface['tgtConcept'];
		
		// Set datatype of tgtConcept
		switch($this->tgtConcept){
			// <input> types
			case "TEXT":
				$this->tgtDataType = "text";		// relation to TEXT concept
				break;
			case "DATE":
				$this->tgtDataType = "date";		// relation to DATE concept
				break;
			case "BOOL":
				$this->tgtDataType = "checkbox";	// relation to BOOL concept
				break;
			case "PASSWORD":
				$this->tgtDataType = "password"; 	// relation to PASSWORD concept
				break;
			case "BLOB":
				$this->tgtDataType = "textarea"; 	// relation to BLOB concept
				break;
			default:
				$this->tgtDataType = "concept"; 	// relation to other concept
		}
		
		// Information about subinterfaces
		$this->refInterface = $interface['refSubInterface'];
		$refInterfacesArr[] = $this->name;
		if(in_array($this->refInterface, $refInterfacesArr)) throw new Exception("Infinite loop in interface '$this->name' by referencing '$this->refInterface'", 500);
		
		$this->boxSubInterfaces = $interface['boxSubInterfaces'];
		$this->expressionSQL = $interface['expressionSQL'];
		
		// Determine subInterfaces
		if(!empty($this->refInterface)){
					
			$refInterface = new ObjectInterface($this->refInterface, null, $refInterfacesArr);
			foreach($refInterface->subInterfaces as $subInterface){
				$this->subInterfaces[] = $subInterface;
			}
		}else{
			foreach ((array)$this->boxSubInterfaces as $subInterface){
				$this->subInterfaces[] = new ObjectInterface($subInterface['name'], $subInterface, $refInterfacesArr);
			}
		}
	}
	
	public function getInterface(){
		
		return $this;
				
	}
	
	
	public static function isInterfaceForRole($roleName, $interfaceName = null){
		if(isset($interfaceName)){
			$interface = new ObjectInterface($interfaceName);
			return (in_array($roleName, $interface->interfaceRoles) or empty($interface->interfaceRoles));
		}		
		
		return (in_array($roleName, $this->interfaceRoles) or empty($this->interfaceRoles));
	}
	
	public static function getSubinterface($interface, $subinterfaceName){
		
		foreach((array)$interface->subInterfaces as $subinterface){
			if($subinterface->name == $subinterfaceName) {
				$result = $subinterface;
			}
		}
		return empty($result) ? false : $result;
	}
}

?>