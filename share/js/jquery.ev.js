/* Title: jQuery ev
 *
 * A COMET event loop for jQuery
 *
 * $.ev.loop long-polls on a URL and expects to get an array of JSON-encoded
 * objects back.  Each of these objects should represent a message from the COMET
 * server that's telling your client-side Javascript to do something.
 *
 */
(function($){

  $.ev = {

    handlers : {},
    running  : false,
    xhr      : null,
    verbose  : true,
    timeout  : null,

    run: function(events) {
      var i;
      for (i = 0; i < events.length; i++) {
        var e = events[i];
        if (!e) continue;
        var h = this.handlers[e.type];
        if (h) h(e);
      }
    },

    /* Method: stop
     *
     * Stop the loop
     *
     */
    stop: function() {
      if (this.xhr) {
        this.xhr.abort();
        this.xhr = null;
      }
      this.running = false;
    },

    /* 
     * Method: loop
     *
     * Arguments:
     * 
     *   url
     *   handler
     *
     */
    loop: function(url, handlers) {
      var self = this;
      if (handlers) {
        this.handlers = handlers;
      }
      this.running = true;
      this.xhr = $.ajax({
        type     : 'GET',
        dataType : 'json',
        url      : url,
        timeout  : self.timeout,
        success  : function(events, status) {
          // console.log('success', events);
          self.run(events)
        },
        complete : function(xhr, status) {
          var delay;
          if (status == 'success') {
            delay = 100;
          } else {
            // console.log('status: ' + status, '; waiting before long-polling again...');
            delay = 5000;
          }
          window.setTimeout(function(){
            if (self.running) self.loop(url);
          }, delay);
        }
      });
    }

  };

})(jQuery);
