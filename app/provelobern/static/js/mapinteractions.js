goog.provide('app.Drag');

goog.require('app');
goog.require('ol.interaction.Pointer');



/**
 * @constructor
 * @extends {ol.interaction.Pointer}
 * @param {Object} options Drag interaction options.
 */
app.Drag = function(options) {

  ol.interaction.Pointer.call(this, {
    handleDownEvent: app.Drag.prototype.handleDownEvent,
    handleDragEvent: app.Drag.prototype.handleDragEvent,
    handleMoveEvent: app.Drag.prototype.handleMoveEvent,
    handleUpEvent: app.Drag.prototype.handleUpEvent
  });

  /**
   * @type {ol.Pixel}
   * @private
   */
  this.coordinate_ = null;

  /**
   * @type {string|undefined}
   * @private
   */
  this.cursor_ = 'pointer';

  /**
   * @type {ol.Feature}
   * @private
   */
  this.feature_ = null;

  /**
   * @type {string|undefined}
   * @private
   */
  this.previousCursor_ = undefined;

  this.layerFilter_ = options.layerFilter;

  this.layerFilterThis_ = options.layerFilterThis;

};
ol.inherits(app.Drag, ol.interaction.Pointer);


/**
 * @param {ol.MapBrowserEvent} evt Map browser event.
 * @return {boolean} `true` to start the drag sequence.
 */
app.Drag.prototype.handleDownEvent = function(evt) {
  var map = evt.map;

  var feature = map.forEachFeatureAtPixel(evt.pixel,
      function(feature, layer) {
        return feature;
      }, this, this.layerFilter_, this.layerFilterThis_);

  if (feature) {
    this.coordinate_ = evt.coordinate;
    this.feature_ = feature;
  }

  return !!feature;
};


/**
 * @param {ol.MapBrowserEvent} evt Map browser event.
 */
app.Drag.prototype.handleDragEvent = function(evt) {
  var map = evt.map;

  var feature = map.forEachFeatureAtPixel(evt.pixel,
      function(feature, layer) {
        return feature;
      }, this, this.layerFilter_, this.layerFilterThis_);

  var deltaX = evt.coordinate[0] - this.coordinate_[0];
  var deltaY = evt.coordinate[1] - this.coordinate_[1];

  var geometry = /** @type {ol.geom.SimpleGeometry} */
      (this.feature_.getGeometry());
  geometry.translate(deltaX, deltaY);

  this.coordinate_[0] = evt.coordinate[0];
  this.coordinate_[1] = evt.coordinate[1];
};


/**
 * @param {ol.MapBrowserEvent} evt Event.
 */
app.Drag.prototype.handleMoveEvent = function(evt) {
  if (this.cursor_) {
    var map = evt.map;
    var feature = map.forEachFeatureAtPixel(evt.pixel,
        function(feature, layer) {
          return feature;
        }, this, this.layerFilter_, this.layerFilterThis_);
    var element = evt.map.getTargetElement();
    if (feature) {
      if (element.style.cursor != this.cursor_) {
        this.previousCursor_ = element.style.cursor;
        element.style.cursor = this.cursor_;
      }
    } else if (this.previousCursor_ !== undefined) {
      element.style.cursor = this.previousCursor_;
      this.previousCursor_ = undefined;
    }
  }
};


/**
 * @param {ol.MapBrowserEvent} evt Map browser event.
 * @return {boolean} `false` to stop the drag sequence.
 */
app.Drag.prototype.handleUpEvent = function(evt) {
  if (this.feature_ !== null) {
    this.dispatchEvent(
        new app.Drag.DragEvent(app.Drag.FEATUREDRAGEND, this.feature_));
  }
  this.coordinate_ = null;
  this.feature_ = null;
  return false;
};



/**
 * @constructor
 * @extends {goog.events.Event}
 * @param {string} type Type.
 * @param {ol.Feature} feature Feature.
 * @param {Object=} opt_target Target.
 */
app.Drag.DragEvent = function(type, feature, opt_target) {

  goog.base(this, type, opt_target);

  /**
   * The feature that was dragged.
   * @type {ol.Feature}
   */
  this.feature = feature;

};
goog.inherits(app.Drag.DragEvent, goog.events.Event);


/**
 * Triggered after a feature was dragged.
 * @event
 */
app.Drag.FEATUREDRAGEND = 'featuredragend';
