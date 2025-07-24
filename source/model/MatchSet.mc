import Toybox.Lang;
import Toybox.Time;

class MatchSetRally {
//	const INITIAL_SIZE = 10;

	private var scorer as Team?;
	private var score as Number;

	function initialize(_scorer as Team) {
		scorer = _scorer;
		score = 0;
	}


	function get() as MatchSetRally{
		return self;
	}
	function getScorer() as Team{
		return scorer;
	}
	function getScore() as Number{
		return score;
	}



	function addScore(add as Number) {
		score += add;
	}
}
class MatchSet {

	private var rallies as List; //list of all rallies

	private var scores as Dictionary<Team, Number>; //dictionary containing teams current scores
	private var winner as Team?; //store the winner of the match, USER or OPPONENT

	private var beginningTime as Moment; //datetime of the beginning of the set
	private var duration as Duration?; //store duration of the set (do not store the datetime of the end of the set to reduce memory footprint)
	private var ralliesTime as Moment?; //store duration of the rally (do not store the datetime of the end of the set to reduce memory footprint)

	function initialize() {
		rallies = new List();
		scores = {USER => 0, OPPONENT => 0} as Dictionary<Team, Number>;
		beginningTime = Time.now();
		ralliesTime = Time.now();
	}

	function end(team as Team) as Void {
		winner = team;
		duration = Time.now().subtract(beginningTime) as Duration;
	}

	function hasEnded() as Boolean {
		return winner != null;
	}

	function getWinner() as Team? {
		return winner;
	}

	function getRallies() as List {
		return rallies;
	}

	function getDuration() as Duration? {
		return duration;
	}

	function score(scorer as Team) as Void {
		if(hasEnded()) {
			throw new OperationNotAllowedException("Unable to score in a set that has ended");
		}

		var rally = (rallies.size() > 0) ? rallies.last() as MatchSetRally : null;
		System.println(rally);

		if (rallies.size() == 0 || ralliesTime.compare(Time.now()) < -10 or (rally != null and rally.getScorer() != scorer)){
			rallies.push(new MatchSetRally(scorer as Team));
			rally = rallies.last();
			ralliesTime = Time.now();
		}
		var score = scores[scorer] as Number;
		scores[scorer] = score + 1;
		rally.addScore(1);
	}

	function undo() as Void {
		if(rallies.size() > 0) {
			winner = null;
			var rally = rallies.pop() as MatchSetRally;
			var score = scores[rally.getScorer()] as Number;
			scores[rally.getScorer()] = score - rally.getScore();
		}
	}

	function getRalliesNumber() as Number {
		return rallies.size();
	}

	function getScore(team as Team) as Number {
		return scores[team] as Number;
	}
}
