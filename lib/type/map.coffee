'use strict'
Type = require('../type')
module.exports = new Type('tag:yaml.org,2002:map',
    kind: 'mapping'
    construct: (data) ->
        if data != null then data else {}
)
