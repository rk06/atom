Range = require 'range'
_ = require 'underscore'
EventEmitter = require 'event-emitter'

module.exports =
class DisplayBufferMarker
  bufferMarkerSubscription: null
  headScreenPosition: null
  tailScreenPosition: null
  valid: true

  ###
  # Internal #
  ###

  constructor: ({@bufferMarker, @displayBuffer}) ->
    @id = @bufferMarker.id

  ###
  # Public #
  ###

  # Public: Gets the screen range of the display marker.
  #
  # Returns a {Range}.
  getScreenRange: ->
    @displayBuffer.screenRangeForBufferRange(@getBufferRange(), wrapAtSoftNewlines: true)

  # Public: Modifies the screen range of the display marker.
  #
  # screenRange - The new {Range} to use
  # options - A hash of options matching those found in {BufferMarker.setRange}
  setScreenRange: (screenRange, options) ->
    @setBufferRange(@displayBuffer.bufferRangeForScreenRange(screenRange), options)

  # Public: Gets the buffer range of the display marker.
  #
  # Returns a {Range}.
  getBufferRange: ->
    @bufferMarker.getRange()

  # Public: Modifies the buffer range of the display marker.
  #
  # screenRange - The new {Range} to use
  # options - A hash of options matching those found in {BufferMarker.setRange}
  setBufferRange: (bufferRange, options) ->
    @bufferMarker.setRange(bufferRange, options)

  # Public: Retrieves the screen position of the marker's head.
  #
  # Returns a {Point}.
  getHeadScreenPosition: ->
    @headScreenPosition ?= @displayBuffer.screenPositionForBufferPosition(@getHeadBufferPosition(), wrapAtSoftNewlines: true)

  # Public: Sets the screen position of the marker's head.
  #
  # screenRange - The new {Point} to use
  # options - A hash of options matching those found in {DisplayBuffer.bufferPositionForScreenPosition}
  setHeadScreenPosition: (screenPosition, options) ->
    screenPosition = @displayBuffer.clipScreenPosition(screenPosition, options)
    @setHeadBufferPosition(@displayBuffer.bufferPositionForScreenPosition(screenPosition, options))

  # Public: Retrieves the buffer position of the marker's head.
  #
  # Returns a {Point}.
  getHeadBufferPosition: ->
    @bufferMarker.getHeadPosition()

  # Public: Sets the buffer position of the marker's head.
  #
  # screenRange - The new {Point} to use
  # options - A hash of options matching those found in {DisplayBuffer.bufferPositionForScreenPosition}
  setHeadBufferPosition: (bufferPosition) ->
    @bufferMarker.setHeadPosition(bufferPosition)

  # Public: Retrieves the screen position of the marker's tail.
  #
  # Returns a {Point}.
  getTailScreenPosition: ->
    @tailScreenPosition ?= @displayBuffer.screenPositionForBufferPosition(@getTailBufferPosition(), wrapAtSoftNewlines: true)

  # Public: Sets the screen position of the marker's tail.
  #
  # screenRange - The new {Point} to use
  # options - A hash of options matching those found in {DisplayBuffer.bufferPositionForScreenPosition}
  setTailScreenPosition: (screenPosition, options) ->
    screenPosition = @displayBuffer.clipScreenPosition(screenPosition, options)
    @setTailBufferPosition(@displayBuffer.bufferPositionForScreenPosition(screenPosition, options))

  # Public: Retrieves the buffer position of the marker's tail.
  #
  # Returns a {Point}.
  getTailBufferPosition: ->
    @bufferMarker.getTailPosition()

  # Public: Sets the buffer position of the marker's tail.
  #
  # screenRange - The new {Point} to use
  # options - A hash of options matching those found in {DisplayBuffer.bufferPositionForScreenPosition}
  setTailBufferPosition: (bufferPosition) ->
    @bufferMarker.setTailPosition(bufferPosition)

  # Public: Sets the marker's tail to the same position as the marker's head.
  #
  # This only works if there isn't already a tail position.
  #
  # Returns a {Point} representing the new tail position.
  placeTail: ->
    @bufferMarker.placeTail()

  # Public: Removes the tail from the marker.
  clearTail: ->
    @bufferMarker.clearTail()

  # Public: Sets a callback to be fired whenever the marker is changed.
  #
  # callback - A {Function} to execute
  observe: (callback) ->
    @observeBufferMarkerIfNeeded()
    @on 'changed', callback
    cancel: => @unobserve(callback)

  # Public: Removes the callback that's fired whenever the marker changes.
  #
  # callback - A {Function} to remove
  unobserve: (callback) ->
    @off 'changed', callback
    @unobserveBufferMarkerIfNeeded()

  # Returns whether the head precedes the tail in the buffer
  isReversed: ->
    @bufferMarker.isReversed()

  destroy: ->
    delete @displayBuffer.markers[@id]
    @bufferMarker.destroy()

  ###
  # Internal #
  ###

  observeBufferMarkerIfNeeded: ->
    return if @subscriptionCount()
    @getHeadScreenPosition() # memoize current value
    @getTailScreenPosition() # memoize current value
    @bufferMarkerSubscription =
      @bufferMarker.observe ({oldHeadPosition, newHeadPosition, oldTailPosition, newTailPosition, bufferChanged, valid}) =>
        @notifyObservers
          oldHeadBufferPosition: oldHeadPosition
          newHeadBufferPosition: newHeadPosition
          oldTailBufferPosition: oldTailPosition
          newTailBufferPosition: newTailPosition
          bufferChanged: bufferChanged
          valid: valid
    @displayBuffer.markers[@id] = this

  unobserveBufferMarkerIfNeeded: ->
    return if @subscriptionCount()
    @bufferMarkerSubscription.cancel()
    delete @displayBuffer.markers[@id]

  notifyObservers: ({oldHeadBufferPosition, oldTailBufferPosition, bufferChanged, valid} = {}) ->
    oldHeadScreenPosition = @getHeadScreenPosition()
    newHeadScreenPosition = oldHeadScreenPosition
    oldTailScreenPosition = @getTailScreenPosition()
    newTailScreenPosition = oldTailScreenPosition
    valid ?= true

    if valid
      @headScreenPosition = null
      newHeadScreenPosition = @getHeadScreenPosition()
      @tailScreenPosition = null
      newTailScreenPosition = @getTailScreenPosition()

    validChanged = valid isnt @valid
    headScreenPositionChanged = not _.isEqual(newHeadScreenPosition, oldHeadScreenPosition)
    tailScreenPositionChanged = not _.isEqual(newTailScreenPosition, oldTailScreenPosition)
    return unless validChanged or headScreenPositionChanged or tailScreenPositionChanged

    oldHeadBufferPosition ?= @getHeadBufferPosition()
    newHeadBufferPosition = @getHeadBufferPosition() ? oldHeadBufferPosition
    oldTailBufferPosition ?= @getTailBufferPosition()
    newTailBufferPosition = @getTailBufferPosition() ? oldTailBufferPosition
    @valid = valid

    @trigger 'changed', {
      oldHeadScreenPosition, newHeadScreenPosition,
      oldTailScreenPosition, newTailScreenPosition,
      oldHeadBufferPosition, newHeadBufferPosition,
      oldTailBufferPosition, newTailBufferPosition,
      bufferChanged
      valid
    }

_.extend DisplayBufferMarker.prototype, EventEmitter
