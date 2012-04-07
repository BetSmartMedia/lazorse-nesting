nesting = require '../'
lazorse = require 'lazorse'
assert  = require 'assert'
http    = require 'http'

describe 'A server with widgets, doodads and frobs', ->

  widgets =
    swizzler:
      partNumber: 1234
      description: "It swizzles"
      doodads: [0, 2]

  doodads = [
    {name: 'toggle', frob: 1}
    {name: 'rotary dial', frob: 1}
    {name: 'blinky lights', frob: 0}
  ]

  frobs = [ 'cromulent', 'embiggen' ]

  server = lazorse ->
    @port = 0
    @passErrors = true
    @include nesting()

    @resource '/widgets/{widgetName}':
      shortName: 'widget'
      GET: ->
        widget = {}
        widget[k] = v for k, v of widgets[@widgetName]
        widget.doodads = for id in widget.doodads
          {doodad: @link('doodad', doodadId: ""+id)}
 
        @ok widget

    @resource '/doodads/{doodadId}':
      shortName: 'doodad'
      GET: ->
        doodad = {}
        doodad[k] = v for k, v of doodads[@doodadId]
        doodad.frob = @link 'frob', frobId: ""+doodad.frob
        @ok doodad

    @resource '/frobs/{frobId}':
      shortName: 'frob'
      GET: -> @ok frobs[Number @frobId]


  get = (path, cb) ->
    http.get {path, host: 'localhost', port: server.address().port}, (res) ->
      res.on 'error', (e) -> throw e
      rawBody = ""
      res.on 'data', (d) -> rawBody += d
      res.on 'end', ->
        assert.equal res.statusCode, 200
        cb JSON.parse rawBody

  it 'has a widget', (done) ->

    get '/widgets/swizzler', (res) ->
      assert res
      done()
 
  it 'can nest doodads in widgets', (done) ->
    get '/widgets/swizzler?inline=doodad', (data) ->
      expected = {}
      expected[k] = v for k, v of widgets.swizzler
      expected.doodads = for id in expected.doodads
        {
          doodad: {
            name: doodads[id].name, frob: '/frobs/'+doodads[id].frob
          }
        }
      assert.deepEqual data, expected
      done()

  it 'can recursively nest frobs in doodads in widgets', (done) ->
    get '/widgets/swizzler?inline=doodad,frob&inlineRecursive', (data) ->
      expected = {}
      expected[k] = v for k, v of widgets.swizzler
      expected.doodads = for id in expected.doodads
        {
          doodad: { name: doodads[id].name, frob: frobs[doodads[id].frob] }
        }
      console.log data
      assert.deepEqual data, expected
      done()

