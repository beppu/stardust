jQuery(function(){

  jQuery('h4').toggle(
    function(ev){
      jQuery('#js').show('fast');
      jQuery('h4 span').html('Hide');
    },
    function(ev){
      jQuery('#js').hide('fast');
      jQuery('h4 span').html('Show');
    }
  );

  var clientId = Math.random().toString().replace(/\./, '');
  if ($demo == "CurlCommands") {
    jQuery.ev.loop($base+'/channel/curl_commands/stream/'+clientId, {
      Greeting: function(m){
        jQuery('#messages').prepend('<li>'+m.message+'</li>');
      },
      Color: function(m){
        jQuery('body').css({ backgroundColor: m.color });
      },
      '*': function(m){
        try {
          jQuery('#messages').prepend('<li>'+m.toSource()+'</li>');
        }
        catch(e) { }
      }
    });
  } else if ($demo == 'ColorfulBoxes') {
    jQuery('#color-picker').submit(function(ev){ return false; });
    jQuery.ev.loop($base+'/channel/colorful_boxes/stream/'+clientId, {
      ColorBox: function(m){
        try {
          console.log(m.toSource());
        }
        catch(e){ }
        jQuery('#'+m.id).css({ backgroundColor: m.color }); 
      }
    });
    jQuery('td.box').mouseover(function(ev){
      var color = jQuery('#color-picker input').val() || '#ccf';
      jQuery.post($base+'/demo/colorful_boxes', { id: this.id, color: color }, function(response){ });
    })
  } else {
    // console.log('no demo');
  }
});
