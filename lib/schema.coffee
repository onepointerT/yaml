compileList = (schema, name) ->
    result = []
    schema[name].forEach (currentType) ->
        newIndex = result.length
        result.forEach (previousType, previousIndex) ->
            if previousType.tag == currentType.tag and previousType.kind == currentType.kind and previousType.multi == currentType.multi
                newIndex = previousIndex
            return
        result[newIndex] = currentType
        return
    result

compileMap = ->
    result = 
        scalar: {}
        sequence: {}
        mapping: {}
        fallback: {}
        multi:
            scalar: []
            sequence: []
            mapping: []
            fallback: []
    index = undefined
    length = undefined

    collectType = (type) ->
        if type.multi
            result.multi[type.kind].push type
            result.multi['fallback'].push type
        else
            result[type.kind][type.tag] = result['fallback'][type.tag] = type
        return

    index = 0
    length = arguments.length
    while index < length
        arguments[index].forEach collectType
        index += 1
    result

Schema = (definition) ->
    @extend definition

'use strict'

###eslint-disable max-len###

YAMLException = require('./exception')
Type = require('./type')

Schema::extend = (definition) ->
    implicit = []
    explicit = []
    if definition instanceof Type
        # Schema.extend(type)
        explicit.push definition
    else if Array.isArray(definition)
        # Schema.extend([ type1, type2, ... ])
        explicit = explicit.concat(definition)
    else if definition and (Array.isArray(definition.implicit) or Array.isArray(definition.explicit))
        # Schema.extend({ explicit: [ type1, type2, ... ], implicit: [ type1, type2, ... ] })
        if definition.implicit
            implicit = implicit.concat(definition.implicit)
        if definition.explicit
            explicit = explicit.concat(definition.explicit)
    else
        throw new YAMLException('Schema.extend argument should be a Type, [ Type ], ' + 'or a schema definition ({ implicit: [...], explicit: [...] })')
    implicit.forEach (type) ->
        if !(type instanceof Type)
            throw new YAMLException('Specified list of YAML types (or a single Type object) contains a non-Type object.')
        if type.loadKind and type.loadKind != 'scalar'
            throw new YAMLException('There is a non-scalar type in the implicit list of a schema. Implicit resolving of such types is not supported.')
        if type.multi
            throw new YAMLException('There is a multi type in the implicit list of a schema. Multi tags can only be listed as explicit.')
        return
    explicit.forEach (type) ->
        if !(type instanceof Type)
            throw new YAMLException('Specified list of YAML types (or a single Type object) contains a non-Type object.')
        return
    result = Object.create(Schema.prototype)
    result.implicit = (@implicit or []).concat(implicit)
    result.explicit = (@explicit or []).concat(explicit)
    result.compiledImplicit = compileList(result, 'implicit')
    result.compiledExplicit = compileList(result, 'explicit')
    result.compiledTypeMap = compileMap(result.compiledImplicit, result.compiledExplicit)
    result

module.exports = Schema
