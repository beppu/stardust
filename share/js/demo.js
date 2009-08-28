jQuery(function(){
  var clientId = Math.random().toString().replace(/\./, '');
  jQuery.ev.loop('/comet/channel/foo+bar+baz/stream/'+clientId, {
    Greeting: function(ev){
      jQuery('#events').prepend('<li>'+ev.message+'</li>');
    },
    Color: function(ev){
      jQuery('body').css({ backgroundColor: ev.color });
    }
  });
});
