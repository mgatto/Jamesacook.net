$(document).ready(function() {
	//Highlight the nav item for the current page					   
	var loc = window.location.toString().split("/");

	loc = loc[loc.length - 2];
	var uri = "";
	switch (loc) {
		case "jamesacook.net":
			uri = "/jamesacook.net/index.html";
			break;
		case "sculpture":
			uri = "/jamesacook.net/sculpture/index.html";
			break;
		case "spiel":
			uri = "/jamesacook.net/sculpture/spiel.html";
			break;
		default:
			uri = "";
	}

	$("ul#navigation li a[href=\""+uri+"\"]").parent().addClass("active");
	$("ul#navigation li a[href=\""+uri+"\"]").addClass("active_link");   

	$('img.art').colorbox({
		rel:'group', 
		photo:true, 
		transition: 'fade',
		href:function(){ return this.src; }
	}); 
	
	//$('img#nav1').hover(function() {
	//$(this).attr("src","/images/headerNav/1-over.gif");
	//	}, function() {
	//$(this).attr("src","/images/headerNav/1.gif");
});

//<img src="1.gif" id="nav1" />