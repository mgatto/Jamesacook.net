$(document).ready(function() {
	$("#navigation a").filter(function() {
		var currentURL = window.location.toString().split("/");
	     	return $(this).attr("href") == currentURL[currentURL.length-2];
	}).addClass("active-link").parent().addClass("active");

	//if no match, mark your default one.
	if($("#navigation a").hasClass("active") == false) {
		$("#navigation li:first a").addClass("active-link").parent().addClass("active");
	}
	
	$('a.email').nospam({
	  	replaceText: true,
		filterLevel: 'low'
	});	
});