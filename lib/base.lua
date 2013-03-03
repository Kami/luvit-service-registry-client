--[[
Copyright Tomaz Muraus

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

local Object = require('core').Object
local JSON = require('json')
local querystring = require('querystring')
local https = require('https')
local url = require('url')

local async = require('async')
local KeystoneClient = require('keystone_client').Client

local BaseClient = Object:extend()

local ENDPOINT_URL = 'https://dfw.registry.api.rackspacecloud.com/v1.0'
local AUTH_URL = 'https://identity.api.rackspacecloud.com/v2.0'

function BaseClient:initialize(username, apiKey, region, options)
  local options

  self._username = username
  self._apiKey = apiKey
  self._region = region
  self._options = options
  self._url = ENDPOINT_URL

  options = {username = username, apikey = apiKey}
  self._keystoneClient = KeystoneClient:new(AUTH_URL, options)
end

function BaseClient:_request(path, method, payload, options, callback)
  async.waterfall({
    function(callback)
      self._keystoneClient:tenantIdAndToken(callback)
    end,

    function(result, callback)
      local baseUrl, defaultHeaders, reqOptions

      baseUrl = self._url .. '/' .. result.tenantId .. path
      defaultHeaders = {
        ['X-Auth-Token'] = result.token,
        ['User-Agent'] = 'luvit-service-registry-client',
        ['Content-Type'] = 'application/json'
      }

      if payload then
        payload = JSON.stringify(payload)
        defaultHeaders['Content-Length'] = #payload
      end

      qs = querystring.urlencode(qs)

      if qs then
        path = path .. '?' .. qs
      end

      -- TODO: Refactor
      parsed = url.parse(baseUrl)
      reqOptions = {
        host = parsed.hostname,
        port = tonumber(parsed.port),
        path = parsed.pathname,
        headers = defaultHeaders,
        method = method
      }

      client = https.request(reqOptions, function(res)
        local data = ''
        res:on('data', function(chunk)
          data = data .. chunk
        end)

        res:on('end', function()
          res.body = data
          callback(nil, res)
        end)
      end)

      client:on('error', callback)
      client:done(payload)
    end
    },

    function(err, result)
      callback(err, result)
    end)
end

function BaseClient:_create(path, payload, options, callback)
  self:_request(path, 'POST', payload, options, callback)
end

local exports = {}
exports.BaseClient = BaseClient
return exports
