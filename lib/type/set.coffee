resolveYamlSet = (data) ->
    if data == null
        return true
    key = undefined
    object = data
    for key of object
        `key = key`
        if _hasOwnProperty.call(object, key)
            if object[key] != null
                return false
    true

constructYamlSet = (data) ->
    if data != null then data else {}

'use strict'
Type = require('../type')
_hasOwnProperty = Object::hasOwnProperty
module.exports = new Type('tag:yaml.org,2002:set',
    kind: 'mapping'
    resolve: resolveYamlSet
    construct: constructYamlSet)
