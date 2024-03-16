resolveYamlNull = (data) ->
    if data == null
        return true
    max = data.length
    max == 1 and data == '~' or max == 4 and (data == 'null' or data == 'Null' or data == 'NULL')

constructYamlNull = ->
    null

isNull = (object) ->
    object == null

'use strict'
Type = require('../type')
module.exports = new Type('tag:yaml.org,2002:null',
    kind: 'scalar'
    resolve: resolveYamlNull
    construct: constructYamlNull
    predicate: isNull
    represent:
        canonical: ->
            '~'
        lowercase: ->
            'null'
        uppercase: ->
            'NULL'
        camelcase: ->
            'Null'
        empty: ->
            ''
    defaultStyle: 'lowercase')
