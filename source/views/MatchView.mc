import Toybox.Lang;
import Toybox.Timer;
import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.System;
import Toybox.Activity;
using Toybox.Application;
using Toybox.Application.Properties;
using Toybox.UserProfile;

class MatchBoundaries {

	static const COURT_WIDTH_RATIO = 0.6; //width of the back compared to the front of the court

	static const TIME_HEIGHT = Graphics.getFontHeight(Graphics.FONT_SMALL) * 1.1; //height of timer and clock


	//center of the watch
	public var xCenter as Float;
	public var yCenter as Float;

	public var yMiddle as Float;
	public var yFront as Float;
	public var yBack as Float;

	public var marginHeight as Float;

	public var perspective as Perspective;

	function initialize(match as Match, device as DeviceSettings, elapsed_time as Number?) {
		//calculate margins
		marginHeight = device.screenHeight * (device.screenShape == System.SCREEN_SHAPE_RECTANGLE ? 0.04 : 0.09);
//		var margin_width = device.screenWidth * 0.09;

		//calculate strategic positions
		xCenter = device.screenWidth / 2f;
		yCenter = device.screenHeight / 2f;

		yBack = marginHeight;
		if(Properties.getValue("display_time")) {
			yBack += TIME_HEIGHT;
		}
		yFront = device.screenHeight - marginHeight - TIME_HEIGHT;

		var back_width, front_width;
		var radius = device.screenWidth / 2f;
		//use the available space to draw the court
		front_width = Geometry.chordLength(radius, yFront - yCenter) / 2f;
		back_width = Geometry.chordLength(radius, yCenter - yBack) / 2f;
		//however, this may not result in a good perspective, for example when the current time is displayed
		//in this case, the top and bottom margins are the same, resulting in a court that has the shape of a rectangle
		//perspective must be created it artificially
		if((back_width / front_width) > COURT_WIDTH_RATIO) {
			back_width = front_width * COURT_WIDTH_RATIO;
		}

		if(elapsed_time != null) {
			var half_time = MatchView.ANIMATION_TIME / 2;
			if(elapsed_time < half_time) {
				var width = BetterMath.mean(front_width, back_width);
				var zoom = 0.7 + (0.3 * elapsed_time / half_time);
				front_width = width * zoom;
				back_width = width * zoom;

				//adjust back and front positions
				yBack = (yBack - 25 + 15 - 15 * elapsed_time / half_time);
				yFront = (yFront + 25 - 15 + 15 * elapsed_time / half_time);
			}
			else if(elapsed_time < MatchView.ANIMATION_TIME) {
				var time = elapsed_time - half_time;
				var width = BetterMath.mean(front_width, back_width);
				var width_offset = (front_width - width) * time / half_time;
				front_width = width + width_offset;
				back_width = width - width_offset;

				//adjust back and front positions
				var offset = 25 * time / half_time;
				yBack = yBack - 25 + offset;
				yFront = yFront + 25 - offset;
			}
		}

		yMiddle = BetterMath.mean(yFront, yBack) as Float;

		//perspective is defined by its two side vanishing lines
		perspective = new Perspective(
			[xCenter - front_width, yFront], [xCenter - back_width, yBack],
			[xCenter + front_width, yFront], [xCenter + back_width, yBack]
		);
	}

}

class MatchView extends WatchUi.View {

	const score_separator_type = ":";

	const REFRESH_TIME_ANIMATION = 50;
	const REFRESH_TIME_STANDARD = 1000;
	static const ANIMATION_TIME = 800;

	public var boundaries as MatchBoundaries?;

	private var match as Match;

	private var clock24Hour as Boolean;

	private var startTime as Number;
	private var refreshTime as Number = REFRESH_TIME_STANDARD;
	private var enableAnimation as Boolean;
	private var inAnimation as Boolean = false;
	private var refreshTimer as Timer.Timer;

	function initialize(disable_animation as Boolean) {
		View.initialize();
		match = (Application.getApp() as PetanqueApp).getMatch() as Match;

		clock24Hour = true;

		startTime = System.getTimer();
		refreshTimer = new Timer.Timer();

		enableAnimation = Properties.getValue("enable_animation") as Boolean && !disable_animation;
	}

	function calculateBoundaries(elapsed_time as Number?) as Void {
		var device = System.getDeviceSettings();
		boundaries = new MatchBoundaries(match, device, elapsed_time);
	}

	function onShow() as Void {
		(Application.getApp() as PetanqueApp).getBus().register(self);
		inAnimation = enableAnimation;
		var refresh_time = inAnimation ? REFRESH_TIME_ANIMATION : REFRESH_TIME_STANDARD;
		setRefreshTime(refresh_time);
	}

	function onHide() as Void {
		refreshTimer.stop();
		(Application.getApp() as PetanqueApp).getBus().unregister(self);
	}

	function getElapsedTime() as Number {
		return System.getTimer() - startTime;
	}

	function refresh() as Void {
		WatchUi.requestUpdate();
	}

	function setRefreshTime(time as Number) as Void {
		refreshTime = time;
		refreshTimer.stop();
		refreshTimer.start(method(:refresh), refreshTime, true);
		System.println("set refresh time to " + time);
	}

	function onUpdateSettings() as Void {
		//recalculate boundaries as they may change if "display time" setting is updated
		//calculate the boundaries as they should be after the animation has ended
		calculateBoundaries(ANIMATION_TIME);
		WatchUi.requestUpdate();
	}

	function drawScores(dc as Dc, match as Match) as Void {
		var set = match.getCurrentSet();

		//boundaries cannot be null at this point
		var bd = boundaries as MatchBoundaries;

		var SCORE_PLAYER_1_FONT = Graphics.FONT_NUMBER_THAI_HOT;
		var SCORE_PLAYER_2_FONT = Graphics.FONT_NUMBER_THAI_HOT;
		var score_separator_font = Graphics.FONT_NUMBER_THAI_HOT;
		var SCORE_PLAYER_1_COLOR = Graphics.COLOR_BLUE;
		var SCORE_PLAYER_2_COLOR = Graphics.COLOR_LT_GRAY;
		var score_separator_color = Graphics.COLOR_YELLOW;

		var player_1_coordinates_score = bd.perspective.transform([-0.35, 0.55] as Point2D);
		var player_2_coordinates_score = bd.perspective.transform([0.35, 0.55] as Point2D);
		var score_separator_coordonate = bd.perspective.transform([0, 0.58] as Point2D);

		UIHelpers.drawHighlightedNumber(dc, player_1_coordinates_score[0], player_1_coordinates_score[1], SCORE_PLAYER_1_FONT, set.getScore(USER).toString(), SCORE_PLAYER_1_COLOR, 2, 4);
		UIHelpers.drawHighlightedNumber(dc, score_separator_coordonate[0], score_separator_coordonate[1], score_separator_font, score_separator_type, score_separator_color, 2, 4);
		UIHelpers.drawHighlightedNumber(dc, player_2_coordinates_score[0], player_2_coordinates_score[1], SCORE_PLAYER_2_FONT, set.getScore(OPPONENT).toString(), SCORE_PLAYER_2_COLOR, 2, 4);
	}

	function drawTimer(dc as Dc, match as Match) as Void {
		//boundaries cannot be null at this point
		var bd = boundaries as MatchBoundaries;

		dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			bd.xCenter,
			bd.yFront + MatchBoundaries.TIME_HEIGHT * 0.1 as Float,
			Graphics.FONT_SMALL,
			Helpers.formatDuration(match.getDuration()),
			Graphics.TEXT_JUSTIFY_CENTER
		);
	}

	function drawTime(dc as Dc) as Void {
		//boundaries cannot be null at this point
		var bd = boundaries as MatchBoundaries;

		var time_label = Helpers.formatCurrentTime(clock24Hour);
		dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			bd.xCenter,
			bd.marginHeight - MatchBoundaries.TIME_HEIGHT * 0.1 as Float,
			Graphics.FONT_MEDIUM,
			time_label,
			Graphics.TEXT_JUSTIFY_CENTER
		);
	}

	function drawStats(dc as Dc) as Void {
		var set = match.getCurrentSet();
		var distance = match.getDistance();

		//boundaries cannot be null at this point
		var bd = boundaries as MatchBoundaries;
		var current_rally = WatchUi.loadResource(Rez.Strings.rally) + " " + (set.getRalliesNumber() == 0 ? 1 : set.getRalliesNumber()).toString();

		dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
		dc.drawText(
			bd.xCenter,
			bd.yFront + MatchBoundaries.TIME_HEIGHT * -0.8 as Float,
			Graphics.FONT_TINY,
			current_rally + " / " + distance,
			Graphics.TEXT_JUSTIFY_CENTER
		);
	}

	function onUpdate(dc as Dc) {
		//when onUpdate is called, the entire view is cleared on some watches (reported by users with vivoactive 4 and venu)
		//in the simulator it's not the case for all watches
		//do not try to update only a part of the view
		//clean the entire screen
		dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
		dc.clear();
		if(dc has :setAntiAlias) {
			dc.setAntiAlias(true);
		}

		if(inAnimation) {
			var elapsed_time = getElapsedTime();
			if(elapsed_time > ANIMATION_TIME) {
				inAnimation = false;
				setRefreshTime(REFRESH_TIME_STANDARD);
			}
			calculateBoundaries(elapsed_time);
		}
		else if(boundaries == null) {
			calculateBoundaries(null);
		}

		if(!inAnimation) {
			drawScores(dc, match);
			drawTimer(dc, match);
			drawTime(dc);
			drawStats(dc);
		}
	}
}

class MatchViewDelegate extends WatchUi.BehaviorDelegate {

	private var view as MatchView;

	function initialize(v as MatchView) {
		view = v;
		BehaviorDelegate.initialize();
	}

	function onMenu() {
		var menu = new WatchUi.Menu2({:title => Rez.Strings.menu_title});
		menu.addItem(new WatchUi.MenuItem(Rez.Strings.menu_resume_match, null, :menu_resume_match, null));
		menu.addItem(new WatchUi.MenuItem(Rez.Strings.menu_end_match, null, :menu_end_match, null));
		menu.addItem(new WatchUi.MenuItem(Rez.Strings.menu_reset_match, null, :menu_reset_match, null));
		menu.addItem(new WatchUi.MenuItem(Rez.Strings.menu_exit, null, :menu_exit, null));

		WatchUi.pushView(menu, new MatchMenuDelegate(), WatchUi.SLIDE_IMMEDIATE);
		return true;
	}

	function onKey(event as WatchUi.KeyEvent) {
		if(event.getKey() == KEY_ENTER) {
			return onMenu();
		}
		return false;
	}

	function manageScore(team as Team) as Boolean {
		var match = (Application.getApp() as PetanqueApp).getMatch() as Match;
		match.score(team);
		var winner = match.getCurrentSet().getWinner();
		if(winner != null) {
			WatchUi.switchToView(new ResultView(), new ResultViewDelegate(), WatchUi.SLIDE_IMMEDIATE);
		}
		else {
			WatchUi.requestUpdate();
		}
		return true;
	}

	function onNextPage() {
		//user team scores
		return manageScore(OPPONENT);
	}

	function onPreviousPage() {
		//opponent team scores
		return manageScore(USER);
	}

// ATTENTION REVOIR ICI
// Comme j'ai modifié les rallies pour devenir des mènes le retour ne marche plus

	//undo last action
	function onBack() {
		var match = (Application.getApp() as PetanqueApp).getMatch() as Match;
		if(match.getTotalRalliesNumber() > 0) {
			//undo last rally
			match.undo();
			WatchUi.requestUpdate();
		}
		else {

			//the match can be discarded without configuration because it has not been started yet
			match.discard();
			//return to the initial view
			WatchUi.switchToView(new InitialView(), new InitialViewDelegate(), WatchUi.SLIDE_IMMEDIATE);
			
		}
		return true;
	}

	function onTap(event) {
		if(view.boundaries != null) {
			//boundaries cannot be null at this point
			var bd = view.boundaries as MatchBoundaries;
			if(event.getCoordinates()[1] < bd.yMiddle) {
				//opponent team scores
				manageScore(USER);
			}
			else {
				//user team scores
				manageScore(OPPONENT);
			}
		}
		return true;
	}
}
