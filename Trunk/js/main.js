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
		default:
			uri = "";
	}

//console.log(uri);
	$("ul#navigation li a[href=\""+uri+"\"]").parent().addClass("active");
	$("ul#navigation li a[href=\""+uri+"\"]").addClass("active_link");   
						   
	//$('a.email').nospam({
	//  	replaceText: true,
	//  	filterLevel: 'low'
	//});
});