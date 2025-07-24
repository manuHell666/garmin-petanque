import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.Graphics;

class SaveMatchConfirmationDelegate extends WatchUi.ConfirmationDelegate {

	function initialize() {
		ConfirmationDelegate.initialize();
	}

	function onResponse(value) as Boolean {
		var match = (Application.getApp() as PetanqueApp).getMatch() as Match;
		if(value == CONFIRM_YES) {
			match.save();
		}
		else {
			match.discard();
		}
		WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
		//exit the app
		System.exit();
		//WatchUi.switchToView(new InitialView(), new InitialViewDelegate(), WatchUi.SLIDE_IMMEDIATE);
		//WatchUi.pushView(new InitialView(), new InitialViewDelegate(), WatchUi.SLIDE_IMMEDIATE);
		//return true;
	}
}

class ResultView extends WatchUi.View {

	function initialize() {
		View.initialize();
	}

	function onLayout(dc) {
		setLayout(Rez.Layouts.result(dc));
	}

	function onShow() {
		var match = (Application.getApp() as PetanqueApp).getMatch() as Match;
		var set = match.getCurrentSet();
		//draw end of match text
		var winner = match.getWinner();
		var title_resource = Rez.Strings.end_draw;
		if(winner != null) {
			title_resource = winner == USER ? Rez.Strings.end_you_won : Rez.Strings.end_opponent_won;
		}
		var title_text = WatchUi.loadResource(title_resource) as String;
		(findDrawableById("result_title") as Text).setText(title_text);
		//draw match score
		var match_score_text = (set.getScore(USER) as Text) + " - " + (set.getScore(OPPONENT) as Text);
		(findDrawableById("result_match_score") as Text).setText(match_score_text);
		//draw current set score if the same number of sets has been won by both teams

		//draw match time
		(findDrawableById("result_time") as Text).setText(Helpers.formatDuration(match.getDuration()));
		//draw rallies
		var rallies_text = WatchUi.loadResource(Rez.Strings.total_rallies) as String;
		(findDrawableById("result_rallies") as Text).setText(Helpers.formatString(rallies_text, {"rallies" => match.getTotalRalliesNumber().toString()}));
	}
}

class ResultViewDelegate extends WatchUi.BehaviorDelegate {

	function initialize() {
		BehaviorDelegate.initialize();
	}

	function onSelect() {
		var save_match_confirmation = new WatchUi.Confirmation(WatchUi.loadResource(Rez.Strings.end_save_garmin_connect) as String);
		WatchUi.pushView(save_match_confirmation, new SaveMatchConfirmationDelegate(), WatchUi.SLIDE_IMMEDIATE);
		return true;
	}

	function onBack() {
		return true;
	}

	function onPreviousPage() {
		WatchUi.switchToView(new ActivityStatsView(), new ActivityStatsViewDelegate(), WatchUi.SLIDE_IMMEDIATE);
		return true;
	}

	function onNextPage() as Boolean {
		WatchUi.switchToView(new ResultRalliesView(), new ResultRalliesViewDelegate(), WatchUi.SLIDE_IMMEDIATE);
		return true;
	}
}
