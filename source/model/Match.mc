import Toybox.Lang;
import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.Time;

enum Team {
	USER = 1,
	OPPONENT = 2
}

class MatchConfig {
	public var maximumSets as Number?; //maximum number of sets for this match, null for match in endless mode

	function initialize() {
		self.maximumSets = 1;
	}
}

class Match {
	static const MAX_SETS = 1;

	const TOTAL_SCORE_PLAYER_1_FIELD_ID = 0;
	const TOTAL_SCORE_PLAYER_2_FIELD_ID = 1;
	const RALLY_PLAYER_FIELD_ID = 2;
	const RALLY_SCORE_FIELD_ID = 3;
	/*
	const SET_WON_PLAYER_1_FIELD_ID = 2;
	const SET_WON_PLAYER_2_FIELD_ID = 3;
	const SET_SCORE_PLAYER_1_FIELD_ID = 4;
	const SET_SCORE_PLAYER_2_FIELD_ID = 5;
	*/

	private var config as MatchConfig;

	private var sets as List; //list of played sets
	private var winner as Team?; //store the winner of the match, USER or OPPONENT
	private var ended as Boolean; //store if the match has ended

	private var session as Session;
	private var fieldScorePlayer1 as Field;
	private var fieldScorePlayer2 as Field;
	private var fieldRallyPlayer as Field;
	private var fieldRallyScore as Field;
	/*
	private var fieldSetPlayer1 as Field;
	private var fieldSetPlayer2 as Field;
	private var fieldSetScorePlayer1 as Field;
	private var fieldSetScorePlayer2 as Field;
	*/
	function initialize(config as MatchConfig) {
		self.config = config;
		ended = false;
		sets = new List();

		sets.push(new MatchSet());

		//determine sport and subsport
		//it would be better to use feature detection instead of checking the version, but this does not work, see IQTest.mc
//		var version = System.getDeviceSettings().monkeyVersion;
//		var v410 = version[0] > 4 || version[0] == 4 && version[1] >= 1;
//		var sport = v410 ? Activity.SPORT_WALKING : ActivityRecording.SPORT_GENERIC;
//		var sub_sport = v410 ? Activity.SUB_SPORT_CASUAL_WALKING : ActivityRecording.SUB_SPORT_MATCH;
		var sport = Activity.SPORT_GENERIC;
		var sub_sport = Activity.SUB_SPORT_GENERIC;

		//manage sensors
		//Sensor.setEnabledSensors( [Sensor.SENSOR_HEARTRATE,Sensor.SENSOR_TEMPERATURE,Sensor.SENSOR_FOOTPOD] );
		Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, null);
		//manage activity session
		session = ActivityRecording.createSession({:sport => sport, :subSport => sub_sport, :name => WatchUi.loadResource(Rez.Strings.fit_activity_name) as String});

		fieldScorePlayer1 = session.createField("score_player_1", TOTAL_SCORE_PLAYER_1_FIELD_ID, FitContributor.DATA_TYPE_UINT16, {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => WatchUi.loadResource(Rez.Strings.fit_score_unit_label) as String});
		fieldScorePlayer2 = session.createField("score_player_2", TOTAL_SCORE_PLAYER_2_FIELD_ID, FitContributor.DATA_TYPE_UINT16, {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => WatchUi.loadResource(Rez.Strings.fit_score_unit_label) as String});
		fieldRallyPlayer = session.createField("rally_player", RALLY_PLAYER_FIELD_ID, FitContributor.DATA_TYPE_UINT16, {:mesgType => FitContributor.MESG_TYPE_LAP, :units => WatchUi.loadResource(Rez.Strings.fit_player_label) as String});
		fieldRallyScore = session.createField("rally_score", RALLY_SCORE_FIELD_ID, FitContributor.DATA_TYPE_UINT16, {:mesgType => FitContributor.MESG_TYPE_LAP, :units => WatchUi.loadResource(Rez.Strings.fit_score_unit_label) as String});
		session.start();

		(Application.getApp() as PetanqueApp).getBus().dispatch(new BusEvent(:onMatchBegin, null));
	}

	function save() as Void {
		//session can only be save once
		session.save();
	}

	function discard() as Void {
		session.discard();

		var sport = Activity.SPORT_GENERIC;
		var sub_sport = Activity.SUB_SPORT_EXERCISE;
		session = ActivityRecording.createSession({:sport => sport, :subSport => sub_sport, :name => WatchUi.loadResource(Rez.Strings.fit_activity_name) as String});

		fieldScorePlayer1 = session.createField("score_player_1", TOTAL_SCORE_PLAYER_1_FIELD_ID, FitContributor.DATA_TYPE_UINT16, {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => WatchUi.loadResource(Rez.Strings.fit_score_unit_label) as String});
		fieldScorePlayer2 = session.createField("score_player_2", TOTAL_SCORE_PLAYER_2_FIELD_ID, FitContributor.DATA_TYPE_UINT16, {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => WatchUi.loadResource(Rez.Strings.fit_score_unit_label) as String});
		fieldRallyPlayer = session.createField("rally_player", RALLY_PLAYER_FIELD_ID, FitContributor.DATA_TYPE_UINT16, {:mesgType => FitContributor.MESG_TYPE_LAP, :units => WatchUi.loadResource(Rez.Strings.fit_player_label) as String});
		fieldRallyScore = session.createField("rally_score", RALLY_SCORE_FIELD_ID, FitContributor.DATA_TYPE_UINT16, {:mesgType => FitContributor.MESG_TYPE_LAP, :units => WatchUi.loadResource(Rez.Strings.fit_score_unit_label) as String});
		session.start();
	}

	function end(winner_team as Team?) as Void {
		if(hasEnded()) {
			throw new OperationNotAllowedException("Unable to end a match that has already been ended");
		}
		ended = true;

		var you_sets_won = getSetsWon(USER);
		var opponent_sets_won = getSetsWon(OPPONENT);
		var you_total_score = getTotalScore(USER);
		var opponent_total_score = getTotalScore(OPPONENT);

		//in there is no winner yet, the winner must be determined now
		//this occurs in endless mode, or when the user ends the match manually
		//in standard mode, the winner has already been determined when the last set has been won
		if(winner_team == null) {
			//determine winner based on sets
			if(you_sets_won != opponent_sets_won) {
				winner = you_sets_won > opponent_sets_won ? USER : OPPONENT;
			}
			//determine winner based on total score
			if(winner == null && you_total_score != opponent_total_score) {
				winner = you_total_score > opponent_total_score ? USER : OPPONENT;
			}
		}
		else {
			winner = winner_team;
		}

		//manage activity session
		var set = getCurrentSet();
		fieldScorePlayer1.setData(set.getScore(USER));
		fieldScorePlayer2.setData(set.getScore(OPPONENT));
		System.println("end " + set.getScore(USER) + " - " + set.getScore(OPPONENT));
		session.stop();

		//encapsulate event payload in an object so this object can never be null
		var event = new BusEvent(:onMatchEnd, {"winner" => winner});
		(Application.getApp() as PetanqueApp).getBus().dispatch(event);
	}

	function getMaximumSets() as Number? {
		return config.maximumSets;
	}

	function getCurrentSet() as MatchSet {
		return sets.last() as MatchSet;
	}

	function score(scorer as Team) as Void {
		if(hasEnded()) {
			throw new OperationNotAllowedException("Unable to score in a match that has ended");
		}
		var set = getCurrentSet();
		var before = set.getRalliesNumber() as Number;
		set.score(scorer);
		if (set.getRalliesNumber() != before && isWon() == null){
			session.addLap();
			System.println("addLap");
		}
		fieldRallyPlayer.setData(scorer);
		fieldRallyScore.setData((set.getRallies().last() as MatchSetRally).getScore());

		//end the set if it has been won
		var set_winner = isSetWon(set);
		if(set_winner != null) {
			set.end(set_winner);

			//manage activity session
			/*
			fieldSetScorePlayer1.setData(set.getScore(USER));
			fieldSetScorePlayer2.setData(set.getScore(OPPONENT));
			*/
			fieldScorePlayer1.setData(set.getScore(USER));
			fieldScorePlayer2.setData(set.getScore(OPPONENT));

			if(!isEndless()) {
				var match_winner = isWon();
				if(match_winner != null) {
					end(match_winner);
				}
			}
		}
	}

	private function isSetWon(set as MatchSet) as Team? {
		var scorePlayer1 = set.getScore(USER);
		var scorePlayer2 = set.getScore(OPPONENT);

		if(scorePlayer1 >= 13) {return USER;}
		if(scorePlayer2 >= 13) {return OPPONENT;}
		return null;
	}

	private function isWon() as Team? {
		//in endless mode, no winner can be determined wile the match has not been ended
		if(isEndless()) {
			return null;
		}
		var winning_sets = config.maximumSets as Number / 2; //if not in endless mode, maximum sets cannot be null
		var player_1_sets = getSetsWon(USER);
		if(player_1_sets > winning_sets) {
			return USER;
		}
		var player_2_sets = getSetsWon(OPPONENT);
		if(player_2_sets > winning_sets) {
			return OPPONENT;
		}
		return null;
	}

	function undo() as Void {
		var set = getCurrentSet();
		if(set.getRallies().size() > 0) {
			ended = false;
			winner = null;
			set.undo();
		}
	}

	function getDuration() as Duration {
		var info = Activity.getActivityInfo() as Info;
		var time = info.elapsedTime;
		var seconds = time != null ? time / 1000 : 0;
		return new Time.Duration(seconds);
	}

	function getDistance() as String {
		var info = Activity.getActivityInfo() as Info;
		System.println(info.elapsedDistance);
		var distance = (info.elapsedDistance != null) ? info.elapsedDistance : 0.0;
		System.println(distance);
		System.println(Helpers.formatString("${meters} M", {"meters" => distance.format("%.0d")}));
		System.println(Helpers.formatString(" bite M", {"bite" => "4"}));
		return (distance > 0 && distance != null) ? Helpers.formatString("${meters} M", {"meters" => distance.format("%.0d")}) : "0 M";
	}

	function isEndless() as Boolean {
		return config.maximumSets == null;
	}

	function getSets() as List {
		return sets;
	}

	function hasEnded() as Boolean {
		return ended;
	}

	function getTotalRalliesNumber() as Number {
		var number = 0;
		for(var i = 0; i < sets.size(); i++) {
			var set = sets.get(i) as MatchSet;
			number += set.getRalliesNumber();
		}
		return number;
	}

	function getTotalScore(team as Team) as Number {
		var score = 0;
		for(var i = 0; i < sets.size(); i++) {
			var set = sets.get(i) as MatchSet;
			score += set.getScore(team);
		}
		return score;
	}

	function getSetsWon(team as Team) as Number {
		var won = 0;
		for(var i = 0; i < sets.size(); i++) {
			var set = sets.get(i) as MatchSet;
			if(set.getWinner() == team) {
				won++;
			}
		}
		return won;
	}

	function getWinner() as Team? {
		return winner;
	}	
}
