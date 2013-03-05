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
local timer = require('timer')
local JSON = require('json')
local fmt = require('string').format
local bind = require('utils').bind

local BaseClient = require('./base').BaseClient

local HeartBeater = BaseClient:extend()

-- How many seconds to substract from the actual heartbeat interval to account
-- for latency at different layers
local INTERVAL_PROACTIVE_SECONDS = 3

function HeartBeater:initialize(username, apiKey, region, options, sessionId, initialToken, timeout)
  BaseClient.initialize(self, username, apiKey, region, options)

  self._sessionId = sessionId
  self._heartbeatTimeout = timeout

  self._timeoutId = nil
  self._nextToken = initialToken

  if self._heartbeatTimeout < 15 then
    self._heartbeatInterval = (self._heartbeatTimeout * 0.6)
  else
    self._heartbeatInterval = (self._heartbeatTimeout * 0.8)
  end

  self._stopped = false
end

function HeartBeater:start()
  self:_startHeartbeating()
end

function HeartBeater:stop()
  self._stopped = true

  if self._timeoutId then
    timer.clearTimer(self._timeoutId)
    self._timeoutId = nil
  end
end

function HeartBeater:_startHeartbeating()
  local path, payload, interval

  path = fmt('/sessions/%s/heartbeat', self._sessionId)
  payload = {token = self._nextToken}

  if self._stopped then
    return
  end

  interval = (self._heartbeatInterval - INTERVAL_PROACTIVE_SECONDS)

  if interval <= 0 then
    interval = (interval + INTERVAL_PROACTIVE_SECONDS)
  end

  interval = (interval * 1000)

  self:_request(path, 'POST', payload, {['expectedStatusCode'] = 200}, function(err, res)
    if err then
      if err.code and err.code ~= 404 then
        -- Non 404 error, immediately re-try heartbeating with the same token
        self._timeoutId = timer.setTimeout(10, bind(self._startHeartbeating, self))
      else
        self:emit('error', err)
      end

      return
    end

    self._nextToken = JSON.parse(res.body).token
    self._timeoutId = timer.setTimeout(interval, bind(self._startHeartbeating, self))
  end)
end

local exports = {}
exports.HeartBeater = HeartBeater
return exports
