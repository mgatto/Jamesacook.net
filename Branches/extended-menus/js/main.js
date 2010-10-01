$(document).ready(function() {
	//Highlight the nav item for the current page					   
	var loc = window.location.toString().split("/");

	loc = loc[loc.length - 2];
	var uri = "";
	switch (loc) {
		case "jamesacook.net":
			uri = "/index.html";
			break;
		case "sculpture":
			uri = "/sculpture/index.html";
			break;
		case "mediated-sculpture":
			uri = "/mediated-sculpture/index.html";
			break;
		case "video":
			uri = "/video/index.html";
			break;
		case "spiel":
			uri = "/spiel/index.html";
			break;
		default:
			uri = "";
	}

	$("ul#navigation li a[href=\""+uri+"\"]").parent().addClass("active");
	$("ul#navigation li a[href=\""+uri+"\"]").addClass("active_link");
	
	//Colorbox
	if(jQuery().colorbox) {	
		$('img.art').colorbox({
			rel:'group', 
			photo:true, 
			transition: 'fade',
			href: function(){ 
				return this.src; 
			}
		});
	}
});