jQuery.fn.nospam = function(settings) {
	settings = jQuery.extend({
		replaceText: false, 	// optional, accepts true or false
		filterLevel: 'normal' 	// optional, accepts 'low' or 'normal'
	}, settings);
	return this.each(function(){
		e = null;
		if(settings.filterLevel == 'low') { // Can be a switch() if more levels added
			if($(this).is('a[rel]')) {
				e = $(this).attr('rel').replace('//', '@').replace(/\//g, '.');
			} else {
				e = $(this).text().replace('//', '@').replace(/\//g, '.');
			}
		} else { // 'normal'
			if($(this).is('a[rel]')) {
				e = $(this).attr('rel').split('').reverse().join('').replace('//', '@').replace(/\//g, '.');
			} else {
				e = $(this).text().split('').reverse().join('').replace('//', '@').replace(/\//g, '.');
			}
		}
		if(e) {
			if($(this).is('a[rel]')) {
				$(this).attr('href', 'mailto:' + e);
				if(settings.replaceText) {
					$(this).text(e);
				}
			} else {
				$(this).text(e);
			}
		}
	});
};