goog.provide('app.Favorites');

goog.require('app');
goog.require('goog.json');



/**
 * @param {angularLocalStorage.localStorageService} localStorageService
 *        LocalStorage service.
 * @constructor
 */
app.Favorites = function(localStorageService) {

  /**
   * @private
   */
  this.localStorage_ = localStorageService;

};


/**
 * @param {string} name The name of the favorite.
 * @param {string} label The label.
 * @param {ol.Coordinate} coordinate The coordinate.
 */
app.Favorites.prototype.set = function(name, label, coordinate) {
  this.localStorage_.set(name, goog.json.serialize({
    'label': label,
    'coord': coordinate}));
};


/**
 * @return {Array<Object>} Favorites.
 */
app.Favorites.prototype.getFavorites = function() {
  var keys = this.localStorage_.keys();

  var favorites = [];
  goog.array.map(keys, function(key) {
    // var entry = goog.json.parse(this.localStorage_.get(key));
    var entry = this.localStorage_.get(key);

    if (entry !== null) {
      entry['type'] = 'favorite';
      entry['name'] = key;
      entry['geometry'] = new ol.geom.Point(entry['coord']);
      favorites.push(entry);
    }
  }, this);

  return favorites;
};
