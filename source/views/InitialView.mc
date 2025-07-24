import Toybox.Lang;
import Toybox.System;
using Toybox.Application.Properties;
using Toybox.WatchUi;
using Toybox.Graphics;

class InitialView extends WatchUi.View {
	function initialize() {
		System.println("init");
		View.initialize();
		//it's not possible to start the application with a picker view
		//and it's not possible to push a view during the initialization of an other view
	}

	function onShow() {
		//create match
		var match = new Match();

		var app = Application.getApp() as PetanqueApp;
		app.setMatch(match);

		//go to match view
		var view = new MatchView(false);
		WatchUi.switchToView(view, new MatchViewDelegate(view), WatchUi.SLIDE_IMMEDIATE);
	}
}

class InitialViewDelegate extends WatchUi.BehaviorDelegate {

	function initialize() {
		BehaviorDelegate.initialize();
	}

	function onBack() {
		//pop the current view, which is necessarily a picker
		//this will discard the current picker, and display this view (that is under the picker in the view stack)
		//if the picker that was displayed is the first, the application will close itself (when the onShow is executed)
		//if another picker was displayed, the previous picker will be pushed onto the view stack
		WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
		return true;
	}
}

