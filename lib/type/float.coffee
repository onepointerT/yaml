resolveYamlFloat = (data) ->
    if data == null
        return false
    if !YAML_FLOAT_PATTERN.test(data) or data[data.length - 1] == '_'
        return false
    true

constructYamlFloat = (data) ->
    value = undefined
    sign = undefined
    value = data.replace(/_/g, '').toLowerCase()
    sign = if value[0] == '-' then -1 else 1
    if '+-'.indexOf(value[0]) >= 0
        value = value.slice(1)
    if value == '.inf'
        return if sign == 1 then Number.POSITIVE_INFINITY else Number.NEGATIVE_INFINITY
    else if value == '.nan'
        return NaN
    sign * parseFloat(value, 10)

representYamlFloat = (object, style) ->
    res = undefined
    if isNaN(object)
        switch style
            when 'lowercase'
                return '.nan'
            when 'uppercase'
                return '.NAN'
            when 'camelcase'
                return '.NaN'
    else if Number.POSITIVE_INFINITY == object
        switch style
            when 'lowercase'
                return '.inf'
            when 'uppercase'
                return '.INF'
            when 'camelcase'
                return '.Inf'
    else if Number.NEGATIVE_INFINITY == object
        switch style
            when 'lowercase'
                return '-.inf'
            when 'uppercase'
                return '-.INF'
            when 'camelcase'
                return '-.Inf'
    else if common.isNegativeZero(object)
        return '-0.0'
    res = object.toString(10)
    # JS stringifier can build scientific format without dots: 5e-100,
    # while YAML requres dot: 5.e-100. Fix it with simple hack
    if SCIENTIFIC_WITHOUT_DOT.test(res) then res.replace('e', '.e') else res

isFloat = (object) ->
    Object::toString.call(object) == '[object Number]' and (object % 1 != 0 or common.isNegativeZero(object))

'use strict'
common = require('../common')
Type = require('../type')
YAML_FLOAT_PATTERN = new RegExp('^(?:[-+]?(?:[0-9][0-9_]*)(?:\\.[0-9_]*)?(?:[eE][-+]?[0-9]+)?' + '|\\.[0-9_]+(?:[eE][-+]?[0-9]+)?' + '|[-+]?\\.(?:inf|Inf|INF)' + '|\\.(?:nan|NaN|NAN))$')
SCIENTIFIC_WITHOUT_DOT = /^[-+]?[0-9]+e/
module.exports = new Type('tag:yaml.org,2002:float',
    kind: 'scalar'
    resolve: resolveYamlFloat
    construct: constructYamlFloat
    predicate: isFloat
    represent: representYamlFloat
    defaultStyle: 'lowercase')
