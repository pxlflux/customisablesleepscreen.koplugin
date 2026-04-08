-- Reads reading statistics from KOReader's SQLite database.

local logger      = require("logger")
local SQ3         = require("lua-ljsqlite3/init")
local DataStorage = require("datastorage")

local render     = require("infobox_render")
local getSetting = render.getSetting

local function getDbPath()
    return DataStorage:getSettingsDir() .. "/statistics.sqlite3"
end

local function getAllStats(book_id, today_pages_override, goal_type, daily_goal_minutes)
    local result = {
        duration     = 0,
        pages        = 0,
        streak       = 0,
        days_met     = 0,
        days_in_week = 1,
    }

    local ok_conn, conn = pcall(SQ3.open, getDbPath(), SQ3.OPEN_READONLY)
    if not ok_conn or not conn then return result end

    local now         = os.time()
    local now_t       = os.date("*t", now)
    local today_str   = os.date("%Y-%m-%d", now)
    local yesterday   = os.date("%Y-%m-%d", now - 86400)

    local start_today_t = os.date("*t", now)
    start_today_t.hour, start_today_t.min, start_today_t.sec = 0, 0, 0
    local start_today = os.time(start_today_t)

    pcall(function()
        local sql
        if book_id then
            sql = string.format(
                "SELECT SUM(duration), COUNT(DISTINCT page) FROM page_stat_data WHERE start_time >= %d AND id_book = %d",
                start_today, book_id)
        else
            sql = string.format(
                "SELECT SUM(duration), COUNT(DISTINCT page) FROM page_stat_data WHERE start_time >= %d",
                start_today)
        end
        local stmt = conn:prepare(sql)
        if not stmt then error("prepare failed") end
        local row = stmt:step()
        if row then
            result.duration = tonumber(row[1]) or 0
            result.pages    = tonumber(row[2]) or 0
        end
        stmt:close()
    end)

    local dates = {}
    local ok_streak = pcall(function()
        local stmt = conn:prepare(
            "SELECT DISTINCT date(start_time, 'unixepoch', 'localtime') as d FROM page_stat_data ORDER BY d DESC")
        if not stmt then error("prepare failed") end
        for row in stmt:rows() do
            dates[#dates + 1] = row[1]
        end
        stmt:close()
    end)

    if ok_streak and #dates > 0 then
        if dates[1] == today_str or dates[1] == yesterday then
            result.streak = 1
            for i = 2, #dates do
                local prev_date = dates[i - 1]
                local year  = tonumber(prev_date:sub(1, 4))
                local month = tonumber(prev_date:sub(6, 7))
                local day   = tonumber(prev_date:sub(9, 10))
                if year and month and day then
                    local prev_time     = os.time({ year = year, month = month, day = day, hour = 12, min = 0, sec = 0 })
                    local expected_prev = os.date("%Y-%m-%d", prev_time - 86400)
                    if dates[i] == expected_prev then
                        result.streak = result.streak + 1
                    else
                        break
                    end
                else
                    break
                end
            end
        end
    end

    local daily_goal      = tonumber(getSetting("DAILY_GOAL")) or 0
    local goal_type_local = goal_type or getSetting("GOAL_TYPE") or "pages"

    if goal_type_local == "time" then
        local goal_mins    = daily_goal_minutes or getSetting("DAILY_GOAL_MINUTES") or 30
        local goal_seconds = goal_mins * 60

        if goal_seconds > 0 then
            local days_since_monday = (now_t.wday == 1) and 6 or (now_t.wday - 2)
            local start_of_week_t   = os.date("*t", now - (days_since_monday * 86400))
            start_of_week_t.hour, start_of_week_t.min, start_of_week_t.sec = 0, 0, 0
            local start_of_week = os.time(start_of_week_t)

            result.days_in_week = days_since_monday + 1

            local day_durations = {}
            local ok_week = pcall(function()
                local sql = string.format([[
                    SELECT date(start_time, 'unixepoch', 'localtime') AS read_date,
                           SUM(duration) AS day_total
                    FROM page_stat_data
                    WHERE start_time >= %d
                    GROUP BY read_date
                    ORDER BY read_date ASC
                ]], start_of_week)
                local stmt = conn:prepare(sql)
                if not stmt then error("prepare failed") end
                for row in stmt:rows() do
                    day_durations[tostring(row[1])] = tonumber(row[2]) or 0
                end
                stmt:close()
            end)

            if ok_week then
                local today_dur = result.duration
                if today_dur > 0 then
                    day_durations[today_str] = math.max(today_dur, day_durations[today_str] or 0)
                end

                for i = 0, days_since_monday do
                    local date_str = os.date("%Y-%m-%d", now - ((days_since_monday - i) * 86400))
                    if (day_durations[date_str] or 0) >= goal_seconds then
                        result.days_met = result.days_met + 1
                    end
                end
            end
        end

    else
        if daily_goal > 0 then
            local days_since_monday = (now_t.wday == 1) and 6 or (now_t.wday - 2)
            local start_of_week_t   = os.date("*t", now - (days_since_monday * 86400))
            start_of_week_t.hour, start_of_week_t.min, start_of_week_t.sec = 0, 0, 0
            local start_of_week = os.time(start_of_week_t)

            result.days_in_week = days_since_monday + 1

            local day_seen = {}
            local ok_week = pcall(function()
                local sql = string.format([[
                    SELECT date(start_time, 'unixepoch', 'localtime') AS read_date,
                           id_book, page
                    FROM page_stat_data
                    WHERE start_time >= %d
                    ORDER BY read_date ASC
                ]], start_of_week)
                local stmt = conn:prepare(sql)
                if not stmt then error("prepare failed") end
                local row = stmt:step()
                while row do
                    local date_str = tostring(row[1])
                    local key      = tostring(row[2]) .. "-" .. tostring(row[3])
                    if not day_seen[date_str] then day_seen[date_str] = {} end
                    day_seen[date_str][key] = true
                    row = stmt:step()
                end
                stmt:close()
            end)

            if ok_week then
                local day_pages = {}
                for date_str, pages in pairs(day_seen) do
                    local count = 0
                    for _ in pairs(pages) do count = count + 1 end
                    day_pages[date_str] = count
                end

                local effective_today_pages = today_pages_override or result.pages
                if effective_today_pages > 0 then
                    day_pages[today_str] = math.max(effective_today_pages, day_pages[today_str] or 0)
                end

                for i = 0, days_since_monday do
                    local date_str = os.date("%Y-%m-%d", now - ((days_since_monday - i) * 86400))
                    if (day_pages[date_str] or 0) >= daily_goal then
                        result.days_met = result.days_met + 1
                    end
                end
            end
        end
    end

    pcall(conn.close, conn)
    return result
end

local function getDailyStats(stats_source, book_id_override)
    local book_id = nil
    local scope = getSetting("GOAL_STAT_SCOPE") or "all"
    if scope == "book" then
        if book_id_override then
            book_id = tonumber(book_id_override)
        elseif stats_source then
            book_id = tonumber(type(stats_source) == "table" and stats_source.id_curr_book or nil)
            if book_id and book_id < 1 then book_id = nil end
        end
    end
    local r = getAllStats(book_id)
    return r.duration, r.pages
end

local function getCurrentDailyStreak()
    return getAllStats().streak
end

local function getWeeklyGoalAchievement(today_pages_override)
    local goal_type = getSetting("GOAL_TYPE") or "pages"
    if goal_type == "time" then
        local goal_mins = getSetting("DAILY_GOAL_MINUTES") or 30
        if goal_mins <= 0 then return 0, 0 end
        local r = getAllStats(nil, nil, "time", goal_mins)
        return r.days_met, r.days_in_week
    else
        local daily_goal = tonumber(getSetting("DAILY_GOAL")) or 0
        if daily_goal <= 0 then return 0, 0 end
        local r = getAllStats(nil, today_pages_override)
        return r.days_met, r.days_in_week
    end
end

local function getBatteryConsumptionRate()
    local batt_stat_type = getSetting("BATT_STAT_TYPE")
    if batt_stat_type == "manual" then
        return getSetting("BATT_MANUAL_RATE")
    end

    local ok_time,     time_module = pcall(require, "ui/time")
    local ok_settings, LuaSettings = pcall(require, "luasettings")

    if not (ok_time and ok_settings) then return nil end

    local ok_open, batt_settings = pcall(
        LuaSettings.open, LuaSettings,
        DataStorage:getSettingsDir() .. "/battery_stats.lua")

    if not ok_open or not batt_settings then return nil end

    local stat_data = batt_settings:readSetting(batt_stat_type)
    if stat_data
       and type(stat_data.percentage) == "number"
       and type(stat_data.time)       == "number"
       and stat_data.time > 0
       and stat_data.percentage > 0 then
        local time_seconds    = time_module.to_s(stat_data.time)
        local rate_per_second = stat_data.percentage / time_seconds
        if rate_per_second > 0 then
            return rate_per_second * 3600
        end
    end

    return nil
end

return {
    getAllStats                = getAllStats,
    getDailyStats             = getDailyStats,
    getCurrentDailyStreak     = getCurrentDailyStreak,
    getWeeklyGoalAchievement  = getWeeklyGoalAchievement,
    getBatteryConsumptionRate = getBatteryConsumptionRate,
}
