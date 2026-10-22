const MONTHS = [
  "january", "february", "march", "april", "may", "june",
  "july", "august", "september", "october", "november", "december",
]
const WEEKDAYS = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
const SUGGESTION_COUNT = 5
// Includes the next leap day even across a non-leap century.
const LEAP_DAY_SEARCH_YEARS = 8

// Calendar arithmetic uses UTC throughout, independent of the browser's time zone.
// setUTCFullYear also preserves years 1–99 instead of interpreting them as 1901–1999.
function calendarDate(year, month, day) {
  const date = new Date(0)
  date.setUTCFullYear(year, month, day)
  return date
}

function isValidatedDate(year, month, day) {
  const date = calendarDate(year, month, day)
  return year >= 1 && year <= 9999 && date.getUTCFullYear() === year &&
    date.getUTCMonth() === month && date.getUTCDate() === day ? date : null
}

function matchIndex(names, query) {
  return query.length >= 3 ? names.findIndex((name) => name.startsWith(query)) : -1
}

function daysSuggestions(day, today) {
  if (day < 1 || day > 31) return []
  const dates = []
  for (let offset = 0; dates.length < SUGGESTION_COUNT; offset++) {
    const month = calendarDate(today.getUTCFullYear(), today.getUTCMonth() + offset, 1)
    if (month.getUTCFullYear() > 9999) break
    const date = isValidatedDate(month.getUTCFullYear(), month.getUTCMonth(), day)
    if (date && date >= today) dates.push(date)
  }
  return dates
}

function monthsSuggestions(month, day, year, today) {
  if (day === undefined && year === undefined && month === today.getUTCMonth()) return [today]
  day ??= 1
  if (year !== undefined) {
    const date = isValidatedDate(year, month, day)
    return date ? [date] : []
  }

  for (let offset = 0; offset <= LEAP_DAY_SEARCH_YEARS; offset++) {
    const date = isValidatedDate(today.getUTCFullYear() + offset, month, day)
    if (date && date >= today) return [date]
  }
  return []
}

function weekdaysSuggestions(weekday, today) {
  const year = today.getUTCFullYear()
  const month = today.getUTCMonth()
  const day = today.getUTCDate() + (weekday - today.getUTCDay() + 7) % 7
  const nextMonth = calendarDate(year, month + 1, 1)
  return [calendarDate(year, month, day), calendarDate(year, month, day + 7),
    calendarDate(year, month + 1, 1 + (weekday - nextMonth.getUTCDay() + 7) % 7)]
}

// Returns ISO calendar dates. Explicit dates are kept as entered; inferred dates
// start today. Grammar precedence: ISO date, day number, named month, weekday.
export function postponeDates(input, todayISO) {
  // Accept abbreviation dots (Oct., Mon.), never remove punctuation from numbers.
  const query = input.trim().toLowerCase().replace(/\b([a-z]{3,})\.(?=\s|$)/g, "$1")
  if (!query) return []
  const today = new Date(`${todayISO}T00:00:00Z`)
  if (Number.isNaN(today.getTime())) return []

  const day = query.match(/^(\d{4})-(\d{2})-(\d{2})$/)
  const month = query.replace(/^(\d{1,2})\s+([a-z]+)/, "$2 $1")
    .match(/^([a-z]+)(?:\s+(\d{1,2}))?(?:\s+(\d{4}))?$/)
  const monthIndex = month ? matchIndex(MONTHS, month[1]) : -1
  let dates = []

  if (day) {
    const date = isValidatedDate(Number(day[1]), Number(day[2]) - 1, Number(day[3]))
    dates = date ? [date] : []
  } else if (/^\d{1,2}$/.test(query)) {
    dates = daysSuggestions(Number(query), today)
  } else if (monthIndex >= 0) {
    const day = month[2] === undefined ? undefined : Number(month[2])
    const year = month[3] === undefined ? undefined : Number(month[3])
    dates = monthsSuggestions(monthIndex, day, year, today)
  } else {
    const weekday = matchIndex(WEEKDAYS, query)
    if (weekday >= 0) dates = weekdaysSuggestions(weekday, today)
  }

  return [...new Set(dates.filter((date) => date.getUTCFullYear() <= 9999)
    .map((date) => date.toISOString().slice(0, 10)))]
}
