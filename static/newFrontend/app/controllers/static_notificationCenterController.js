AmpersandApp.controller('static_notificationCenterController', function ($scope, $rootScope, $route, $routeParams, $timeout, Restangular, $localStorage) {
	
	$scope.$storage = $localStorage;
	
	// Default preferences for notifications
	if($scope.$storage.notificationPrefs === undefined){
		$scope.$storage.notificationPrefs = {
			  switchShowViolations 		: true
			, switchShowInfos			: false
			, switchShowSuccesses		: true
			, switchAutoHideSuccesses	: true
			, switchShowErrors			: true
			, switchShowInvariants		: true
		}
	}
	
	// Default setting for switchAutoCommit
	if($scope.$storage.switchAutoCommit === undefined){
		$scope.$storage.switchAutoCommit = true;
	}
	
	// Set request type based upon switchAutoCommit
	$rootScope.defaultRequestType = $scope.$storage.switchAutoCommit ? 'promise' : 'feedback';
	$scope.$watch('$storage.switchAutoCommit', function() {
		$rootScope.defaultRequestType = $scope.$storage.switchAutoCommit ? 'promise' : 'feedback';
	});
	
	// Function to update notifications after api response
	$rootScope.updateNotifications = function(notifications){
		$rootScope.notifications = notifications;
		
		if($scope.$storage.switchAutoHideSuccesses){
			$timeout(function() {
		    	$rootScope.notifications.successes = [];
		    }, 3000);
		}
		
		angular.forEach(notifications.logs, function(log) {
			if($scope.$storage.logWindowPrefs.showLogTypes[log.type] == undefined) $scope.$storage.logWindowPrefs.showLogTypes[log.type] = true;
		});
	}
	
	// Function to get notifications again
	$rootScope.getNotifications = function(){
		Restangular.one('notifications/all').get().then(function(data){
			$rootScope.updateNotifications(data);
		});
	}
	
	// Get notification upon application (controller) initialization
	$rootScope.getNotifications();
	
	// Hide success-, error-, info- and invariant violation messages (not process rule violations) upon route change
	$scope.$on("$routeChangeSuccess", function(){
		$rootScope.notifications.successes = [];
		$rootScope.notifications.errors = [];
		$rootScope.notifications.infos = [];
		$rootScope.notifications.invariants = [];
	});
	
	// Function to close notifications
	$scope.closeAlert = function(alerts, index) {
		alerts.splice(index, 1);
	}
	
});
