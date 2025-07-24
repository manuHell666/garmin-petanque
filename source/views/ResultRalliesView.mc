import Toybox.Lang;
import Toybox.WatchUi;
using Toybox.Graphics;

class ResultRalliesView extends WatchUi.View {

	function initialize() {
	    View.initialize();
	}

	function onLayout(dc) {
        var match = (Application.getApp() as PetanqueApp).getMatch() as Match;
		var set = match.getCurrentSet();
        if(set.getRalliesNumber() > 16){
        	setLayout(Rez.Layouts.result_rallies_tiny(dc));
        } else {
    		setLayout(Rez.Layouts.result_rallies(dc));
        }
	}

	function onShow() {
		var match = (Application.getApp() as PetanqueApp).getMatch() as Match;
		var set = match.getCurrentSet();
        var rallies = set.getRallies();

		//draw end of match text
        var score1 = 0;
        var score2 = 0;

        for(var i=0; i < rallies.size(); i++) {
            var rally = rallies.get(i) as MatchSetRally;
            if (rally.getScorer() == USER) {
                score1 += rally.getScore();
            } else {
                score2 += rally.getScore();
            }
            System.println(((i+1) as Text)+": "+(rally.getScorer() as Text)+" "+(score1 as Text)+"-"+(score2 as Text));
            (findDrawableById("rally"+((i+1) as Text)) as Text).setText((score1 as Text)+"-"+(score2 as Text));
        }
        /*
		(findDrawableById("rally1") as Text).setText("01-00");
		(findDrawableById("rally2") as Text).setText("02-00");
		(findDrawableById("rally3") as Text).setText("02-01");
		(findDrawableById("rally4") as Text).setText("02-02");
		(findDrawableById("rally5") as Text).setText("03-02");
		(findDrawableById("rally6") as Text).setText("04-02");
		(findDrawableById("rally7") as Text).setText("05-02");
		(findDrawableById("rally8") as Text).setText("06-02");
		(findDrawableById("rally9") as Text).setText("06-03");
		(findDrawableById("rally10") as Text).setText("06-04");
		(findDrawableById("rally11") as Text).setText("06-05");
		(findDrawableById("rally12") as Text).setText("06-06");
		(findDrawableById("rally13") as Text).setText("06-07");
		(findDrawableById("rally14") as Text).setText("06-08");
		(findDrawableById("rally15") as Text).setText("06-09");
		(findDrawableById("rally16") as Text).setText("06-10");
		(findDrawableById("rally17") as Text).setText("06-11");
		(findDrawableById("rally18") as Text).setText("06-12");
		(findDrawableById("rally19") as Text).setText("07-12");
		(findDrawableById("rally20") as Text).setText("08-12");
		(findDrawableById("rally21") as Text).setText("09-12");
		(findDrawableById("rally22") as Text).setText("10-12");
		(findDrawableById("rally23") as Text).setText("11-12");
		(findDrawableById("rally24") as Text).setText("12-13");
        */
	}
}

class ResultRalliesViewDelegate extends WatchUi.BehaviorDelegate {


	function initialize() {
		BehaviorDelegate.initialize();
	}

	function onBack() {
		return true;
	}

	function onPreviousPage() {
		WatchUi.switchToView(new ResultView(), new ResultViewDelegate(), WatchUi.SLIDE_IMMEDIATE);
		return true;
	}

	function onNextPage() {
		WatchUi.switchToView(new ActivityStatsView(), new ActivityStatsViewDelegate(), WatchUi.SLIDE_IMMEDIATE);
		return true;
	}
}
