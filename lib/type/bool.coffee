resolveYamlBoolean = (data) ->
    if data == null
        return false
    max = data.length
    max == 4 and (data == 'true' or data == 'True' or data == 'TRUE') or max == 5 and (data == 'false' or data == 'False' or data == 'FALSE')

constructYamlBoolean = (data) ->
    data == 'true' or data == 'True' or data == 'TRUE'

isBoolean = (object) ->
    Object::toString.call(object) == '[object Boolean]'

'use strict'
Type = require('../type')
module.exports = new Type('tag:yaml.org,2002:bool',
    kind: 'scalar'
    resolve: resolveYamlBoolean
    construct: constructYamlBoolean
    predicate: isBoolean
    represent:
        lowercase: (object) ->
            if object then 'true' else 'false'
        uppercase: (object) ->
            if object then 'TRUE' else 'FALSE'
        camelcase: (object) ->
            if object then 'True' else 'False'
    defaultStyle: 'lowercase')
