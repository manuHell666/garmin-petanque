import Toybox.Lang;
import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.Time;

enum Team {
	USER = 1,
	OPPONENT = 2
}

class Match {
	static const MAX_SETS = 1;

	const TOTAL_SCORE_PLAYER_1_FIELD_ID = 0;
	const TOTAL_SCORE_PLAYER_2_FIELD_ID = 1;
	const RALLY_SCORE_PLAYER1_FIELD_ID = 2;
	const RALLY_SCORE_PLAYER2_FIELD_ID = 3;

//	private var sets as List; //list of played sets
	private var set as MatchSet; // Played Set
	private var winner as Team?; //store the winner of the match, USER or OPPONENT
	private var ended as Boolean; //store if the match has ended

	private var session as Session;
	private var fieldScorePlayer1 as Field;
	private var fieldScorePlayer2 as Field;
	private var fieldRallyScorePlayer1 as Field;
	private var fieldRallyScorePlayer2 as Field;

	function initialize() {
		ended = false;
		set = new MatchSet();

		//determine sport and subsport

		var sport = Activity.SPORT_GENERIC;
		var sub_sport = Activity.SUB_SPORT_GENERIC;

		//manage sensors
		Sensor.setEnabledSensors( [Sensor.SENSOR_HEARTRATE] );
		if (Application.Properties.getValue("enable_position") as Boolean) {
			if (! Application.Properties.getValue("enable_sound") as Boolean) {
				Attention.playTone(Attention.TONE_START);
			}
			Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, null);
		}
		//manage activity session
		session = ActivityRecording.createSession({:sport => sport, :subSport => sub_sport, :name => WatchUi.loadResource(Rez.Strings.fit_activity_name) as String});

		fieldScorePlayer1 = session.createField("score_player_1", TOTAL_SCORE_PLAYER_1_FIELD_ID, FitContributor.DATA_TYPE_UINT16, {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => WatchUi.loadResource(Rez.Strings.fit_score_unit_label) as String});
		fieldScorePlayer2 = session.createField("score_player_2", TOTAL_SCORE_PLAYER_2_FIELD_ID, FitContributor.DATA_TYPE_UINT16, {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => WatchUi.loadResource(Rez.Strings.fit_score_unit_label) as String});
		fieldRallyScorePlayer1 = session.createField("rally_player", RALLY_SCORE_PLAYER1_FIELD_ID, FitContributor.DATA_TYPE_UINT16, {:mesgType => FitContributor.MESG_TYPE_LAP, :units => WatchUi.loadResource(Rez.Strings.fit_score_unit_label) as String});
		fieldRallyScorePlayer2 = session.createField("rally_score", RALLY_SCORE_PLAYER2_FIELD_ID, FitContributor.DATA_TYPE_UINT16, {:mesgType => FitContributor.MESG_TYPE_LAP, :units => WatchUi.loadResource(Rez.Strings.fit_score_unit_label) as String});
		session.start();

		(Application.getApp() as PetanqueApp).getBus().dispatch(new BusEvent(:onMatchBegin, null));
	}

	function save() as Void {
		//session can only be save once
		session.save();
	}

	function discard() as Void {
		(Application.getApp() as PetanqueApp).disablePosition();
		Sensor.setEnabledSensors([]);
		Sensor.enableSensorEvents(null);
		session.discard();
	}

	function end(winner_team as Team?) as Void {
		(Application.getApp() as PetanqueApp).disablePosition();
		Sensor.setEnabledSensors([]);
		Sensor.enableSensorEvents(null);
		if(hasEnded()) {
			throw new OperationNotAllowedException("Unable to end a match that has already been ended");
		}
		ended = true;

//		var you_sets_won = getSetsWon(USER);
//		var opponent_sets_won = getSetsWon(OPPONENT);
		var you_total_score = getTotalScore(USER);
		var opponent_total_score = getTotalScore(OPPONENT);

		//in there is no winner yet, the winner must be determined now
		//this occurs in endless mode, or when the user ends the match manually
		//in standard mode, the winner has already been determined when the last set has been won
		if(winner_team == null) {
			//determine winner based on sets
			/*
			if(you_sets_won != opponent_sets_won) {
				winner = you_sets_won > opponent_sets_won ? USER : OPPONENT;
			}
			*/
			winner = isWon();
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

	function getCurrentSet() as MatchSet {
		return set;
	}

	function score(scorer as Team) as Void {
		if(hasEnded()) {
			throw new OperationNotAllowedException("Unable to score in a match that has ended");
		}
		var set = getCurrentSet();
		var before = set.getRalliesNumber() as Number;
		set.score(scorer);
		System.println(""+set.getRalliesNumber()+" "+isWon());
		if (set.getRalliesNumber() != before && isWon() == null && before > 0){
			session.addLap();
			System.println("addLap");
		}
		fieldRallyScorePlayer1.setData(set.getScore(USER));
		fieldRallyScorePlayer2.setData(set.getScore(OPPONENT));
		

		//end the set if it has been won
		var set_winner = isSetWon(set);
		if(set_winner != null) {
			set.end(set_winner);

			fieldScorePlayer1.setData(set.getScore(USER));
			fieldScorePlayer2.setData(set.getScore(OPPONENT));

			var match_winner = isWon();
			if(match_winner != null) {
				end(match_winner);
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


	private function isWon() as Team {
		return isSetWon(set);
//		return getSetsWon(USER) > getSetsWon(OPPONENT) ? USER: OPPONENT;
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
		var distance = (info.elapsedDistance != null) ? info.elapsedDistance : 0.0;
		return (distance > 0 && distance != null) ? Helpers.formatString("${meters} M", {"meters" => distance.format("%.0d")}) : "0 M";
	}

	function hasEnded() as Boolean {
		return ended;
	}

	function getTotalRalliesNumber() as Number {
		return set.getRalliesNumber();
	}

	function getTotalScore(team as Team) as Number {
		return set.getScore(team);
	}

/*
	function getSetsWon(team as Team) as Number {
		return (set.getWinner() == team) ? 1 : 0;
	}
*/
	function getWinner() as Team? {
		return winner;
	}	
}
