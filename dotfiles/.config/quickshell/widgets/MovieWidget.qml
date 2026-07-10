import QtQuick
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"

Item {
    id: window
    focus: true

    Caching { id: paths }
    readonly property string moviesCache: paths.getCacheDir("movies")

    Scaler {
        id: scaler
        currentWidth: Screen.width
    }

    function s(val) { 
        return scaler.s(val); 
    }

    MatugenColors { id: _theme }
    readonly property color base: _theme.base
    readonly property color crust: _theme.crust
    readonly property color mantle: _theme.mantle
    readonly property color text: _theme.text
    readonly property color subtext0: _theme.subtext0
    readonly property color surface0: _theme.surface0
    readonly property color surface1: _theme.surface1
    readonly property color surface2: _theme.surface2
    readonly property color mauve: _theme.mauve || "#cba6f7"
    readonly property color blue: _theme.blue || "#89b4fa"
    readonly property color green: _theme.green || "#a6e3a1"
    readonly property color red: _theme.red || "#f38ba8"

    // --- APPLE-STYLE DESIGN TOKENS ---
    // System-style UI typeface stack (falls back gracefully if SF Pro isn't
    // installed on the host machine).
    readonly property string fontUI: ".AppleSystemUIFont, SF Pro Display, SF Pro Text, Inter, Segoe UI, sans-serif"
    // Elevation — one soft, neutral shadow tone used everywhere so depth
    // reads consistently (Apple's "layers of glass" language) instead of the
    // hard 1px borders the old UI leaned on.
    readonly property color shadowColor: Qt.rgba(0, 0, 0, 0.38)
    readonly property color hairline: Qt.rgba(text.r, text.g, text.b, 0.08)
    readonly property color accent: mauve
    // Corner-radius scale (xs → xl), applied consistently instead of ad-hoc
    // per-element numbers.
    function rXS() { return s(8) }
    function rSM() { return s(12) }
    function rMD() { return s(16) }
    function rLG() { return s(20) }
    function rXL() { return s(28) }

    // --- STATE MANAGEMENT ---
    property string currentView: "search" // "search" or "series"
    property string mediaType: "movie" // "movie" or "tv"
    property string filterSort: "Default"
    property bool isSearching: searchInput.text.trim() !== ""
    property bool isSearchingNetwork: false
    property bool isSearchMode: window.isSearching
    property string selectedImdbId: ""
    property string selectedTitle: ""
    property string selectedPoster: ""
    property string selectedDescription: ""
    property var selectedGenres: []
    property var selectedCast: []
    property string selectedTrailerYtId: ""
    property string selectedRatingLabel: ""
    property string selectedBackdrop: ""
    property string selectedYear: ""
    property string selectedRuntime: ""
    property string selectedDirector: ""
    property var similarTitles: []
    property bool isMovieDetail: false
    property var seriesDataMap: ({})
    property int currentSeason: 1
    property bool isLoadingSeries: false
    property bool trendingMoviesLoaded: false
    property bool trendingTvLoaded: false
    property bool isFetchingMovies: false
    property bool isFetchingTv: false
    property bool isLoadingPopular: isFetchingMovies || isFetchingTv
    property var currentFetchResults: []
    property var rawTrendingMovies: []
    property var rawTrendingTv: []
    property real trendingMoviesLastFetch: 0
    property real trendingTvLastFetch: 0
    readonly property real trendingCacheMaxAge: 12 * 60 * 60 * 1000
    property bool seasonSwitching: false
    property bool stateRestored: false
    property bool pendingSeriesFocusRestore: false

    // --- WATCHLIST ---
    property var watchlistIds: ({}) // imdbId -> true, for O(1) "is it in my list" checks

    // --- FILTERS (genre / year / rating) ---
    property bool filterPanelOpen: false
    property var activeGenreFilters: []
    property int minYearFilter: 1950
    property int maxYearFilter: 2026
    property real minRatingFilter: 0
    property bool filtersActive: activeGenreFilters.length > 0 || minYearFilter > 1950 || maxYearFilter < 2026 || minRatingFilter > 0

    // --- OPTIONAL: multi-source ratings (Rotten Tomatoes / Metacritic) ---
    // Cinemeta only ever gives an IMDb score. If you register a free key at
    // https://www.omdbapi.com/apikey.aspx and paste it below, the detail
    // view will also pull Rotten Tomatoes / Metacritic scores for whatever
    // title is open. Leave blank to just show IMDb (default, no setup needed).
    readonly property string omdbApiKey: ""
    property string selectedRTRating: ""
    property string selectedMetacriticRating: ""

    Timer {
        id: safetyLoadingTimer
        interval: 12000
        running: window.isLoadingPopular || window.isSearchingNetwork
        repeat: false
        onTriggered: {
            window.isFetchingMovies = false
            window.isFetchingTv = false
            window.isSearchingNetwork = false
        }
    }

    Timer {
        id: searchDebounceTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (searchInput.text.trim() !== "") {
                doSearch(searchInput.text)
            }
        }
    }

    Timer {
        id: seriesFocusRestoreTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (window.currentView === "series" && !window.isSourceModalOpen) {
                window.forceActiveFocus()
                window.pendingSeriesFocusRestore = false
            }
        }
    }

    // --- SHARED DISK I/O HELPER ---
    function saveJsonToCache(filename, dataObj) {
        let jsStr = JSON.stringify(dataObj)
        Quickshell.execDetached(["bash", "-c", "printf '%s' \"$1\" > " + window.moviesCache + "/" + filename, "_", jsStr])
    }

    // --- PERSISTENT CACHE IO ---
    Process {
        id: readHistoryProc
        command: ["bash", "-c", "cat " + window.moviesCache + "/qs_movie_history.json 2>/dev/null || echo '[]'"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    let parsed = JSON.parse(data.trim())
                    searchHistoryModel.clear()
                    for (let i = parsed.length - 1; i >= 0; i--) {
                        searchHistoryModel.insert(0, { query: parsed[i] })
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: readWatchHistoryProc
        command: ["bash", "-c", "cat " + window.moviesCache + "/qs_movie_watch_history.json 2>/dev/null || echo '[]'"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    let parsed = JSON.parse(data.trim())
                    watchHistoryModel.clear()
                    for (let i = parsed.length - 1; i >= 0; i--) {
                        watchHistoryModel.insert(0, parsed[i])
                    }
                } catch(e) {}
            }
        }
    }

    Process {
        id: readWatchlistProc
        command: ["bash", "-c", "cat " + window.moviesCache + "/qs_movie_watchlist.json 2>/dev/null || echo '[]'"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    let parsed = JSON.parse(data.trim())
                    watchlistModel.clear()
                    let ids = {}
                    for (let i = 0; i < parsed.length; i++) {
                        watchlistModel.append(parsed[i])
                        ids[parsed[i].imdbId] = true
                    }
                    window.watchlistIds = ids
                } catch(e) {}
            }
        }
    }

    function processTrendingCache(parsed, typeStr, targetModel) {
        let now = Date.now()
        let isMovie = typeStr === "movie"
        let lastFetch = parsed[isMovie ? "moviesLastFetch" : "tvLastFetch"] || 0
        let items = parsed[isMovie ? "movies" : "tv"]

        if (items && items.length > 0) {
            targetModel.clear()
            if (isMovie) window.rawTrendingMovies = items; else window.rawTrendingTv = items
            for (let i = 0; i < items.length; i++) targetModel.append(items[i])
            
            if (isMovie) { window.trendingMoviesLoaded = true; window.isFetchingMovies = false; window.trendingMoviesLastFetch = lastFetch } 
            else { window.trendingTvLoaded = true; window.isFetchingTv = false; window.trendingTvLastFetch = lastFetch }
            
            if ((now - lastFetch) > window.trendingCacheMaxAge) fetchTrending(typeStr === "movie" ? "movie" : "series")
        } else {
            fetchTrending(typeStr === "movie" ? "movie" : "series")
        }
    }

    Process {
        id: readTrendingCacheProc
        command: ["bash", "-c", "cat " + window.moviesCache + "/qs_trending_cache.json 2>/dev/null || echo '{}'"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    let parsed = JSON.parse(data.trim())
                    processTrendingCache(parsed, "movie", cachedTrendingMovies)
                    processTrendingCache(parsed, "tv", cachedTrendingTv)
                } catch(e) {
                    fetchTrending("movie")
                    fetchTrending("series")
                }
            }
        }
    }

    Process {
        id: readUiStateProc
        command: ["bash", "-c", "cat " + window.moviesCache + "/qs_ui_state.json 2>/dev/null || echo '{}'"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                try {
                    let s = JSON.parse(data.trim())
                    if (!s || Object.keys(s).length === 0) {
                        window.stateRestored = true
                        return
                    }
                    if (s.mediaType) window.mediaType = s.mediaType
                    if (s.filterSort) {
                        window.filterSort = s.filterSort
                        let idx = filterSelector.model.indexOf(s.filterSort)
                        if (idx >= 0) filterSelector.currentIndex = idx
                    }
                    if (s.searchText && s.searchText !== "") searchInput.text = s.searchText
                    if (s.currentView) window.currentView = s.currentView
                    if (s.selectedImdbId) window.selectedImdbId = s.selectedImdbId
                    if (s.selectedTitle) window.selectedTitle = s.selectedTitle
                    if (s.selectedPoster) window.selectedPoster = s.selectedPoster
                    if (s.selectedDescription) window.selectedDescription = s.selectedDescription
                    if (s.currentSeason) window.currentSeason = s.currentSeason
                    
                    if (s.isSourceModalOpen && s.pendingMedia && s.pendingMedia.imdbId) {
                        window.pendingMedia = s.pendingMedia
                        for (let i = 0; i < sourceModel.count; i++) sourceModel.setProperty(i, "status", "pending")
                        window.isSourceModalOpen = true
                        window.sourceCheckOrder = buildSourceOrder()
                        window.sourceCheckStep = 0
                        window.currentCheckIndex = window.sourceCheckOrder[0]
                        window.checkingState = "checking"
                        window.activeXhrs = {}
                        if (s.foundSourceName) {
                            for (let i = 0; i < sourceModel.count; i++) {
                                if (sourceModel.get(i).name === s.foundSourceName) {
                                    sourceModel.setProperty(i, "status", "success")
                                    break
                                }
                            }
                        }
                        fillCheckSlots()
                    }
                    if (s.currentView === "series" && s.selectedImdbId) {
                        window.pendingSeriesFocusRestore = true
                        if (s.isMovieDetail) {
                            window.isMovieDetail = true
                            loadMovieDetails(s.selectedImdbId, s.selectedTitle || "", s.selectedPoster || "")
                        } else {
                            fetchSeriesData(s.selectedImdbId, s.currentSeason || 1, "", "", true)
                        }
                    }
                    window.stateRestored = true
                } catch(e) {
                    window.stateRestored = true
                }
            }
        }
    }

    property var sourcePrefs: ({})
    Process {
        id: readSourcePrefsProc
        command: ["bash", "-c", "cat " + window.moviesCache + "/qs_source_prefs.json 2>/dev/null || echo '{}'"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                try { window.sourcePrefs = JSON.parse(data.trim()) } 
                catch(e) { window.sourcePrefs = {} }
            }
        }
    }

    // --- SAVING CACHE FUNCTIONS ---
    function saveUiState() {
        saveJsonToCache("qs_ui_state.json", {
            mediaType: window.mediaType, filterSort: window.filterSort, searchText: searchInput.text,
            currentView: window.currentView, selectedImdbId: window.selectedImdbId,
            selectedTitle: window.selectedTitle, selectedPoster: window.selectedPoster,
            selectedDescription: window.selectedDescription, currentSeason: window.currentSeason,
            isSourceModalOpen: window.isSourceModalOpen, checkingState: window.checkingState,
            pendingMedia: window.pendingMedia, foundSourceName: window.foundSourceName,
            isMovieDetail: window.isMovieDetail
        })
    }

    function saveHistory() {
        let arr = []
        for (let i = 0; i < searchHistoryModel.count; i++) arr.push(searchHistoryModel.get(i).query)
        saveJsonToCache("qs_movie_history.json", arr)
    }

    function saveWatchHistory() {
        let arr = []
        for (let i = 0; i < watchHistoryModel.count; i++) {
            let item = watchHistoryModel.get(i)
            arr.push({ imdbId: item.imdbId, title: item.title, poster: item.poster, type: item.type })
        }
        saveJsonToCache("qs_movie_watch_history.json", arr)
    }

    function saveTrendingCache() {
        let cacheObj = { moviesLastFetch: window.trendingMoviesLastFetch, tvLastFetch: window.trendingTvLastFetch, movies: [], tv: [] }
        if (cachedTrendingMovies.count > 0) {
            for (let i = 0; i < cachedTrendingMovies.count; i++) {
                let m = cachedTrendingMovies.get(i)
                cacheObj.movies.push({ imdbId: m.imdbId, title: m.title, poster: m.poster, type: m.type, year: m.year, rating: m.rating || 0, popularity: i })
            }
        }
        if (cachedTrendingTv.count > 0) {
            for (let i = 0; i < cachedTrendingTv.count; i++) {
                let t = cachedTrendingTv.get(i)
                cacheObj.tv.push({ imdbId: t.imdbId, title: t.title, poster: t.poster, type: t.type, year: t.year, rating: t.rating || 0, popularity: i })
            }
        }
        saveJsonToCache("qs_trending_cache.json", cacheObj)
    }

    function saveWatchlist() {
        let arr = []
        for (let i = 0; i < watchlistModel.count; i++) {
            let item = watchlistModel.get(i)
            arr.push({ imdbId: item.imdbId, title: item.title, poster: item.poster, type: item.type })
        }
        saveJsonToCache("qs_movie_watchlist.json", arr)
    }

    function isInWatchlist(imdbId) {
        return !!window.watchlistIds[imdbId]
    }

    function toggleWatchlist(item) {
        if (window.isInWatchlist(item.imdbId)) {
            for (let i = 0; i < watchlistModel.count; i++) {
                if (watchlistModel.get(i).imdbId === item.imdbId) { watchlistModel.remove(i); break }
            }
        } else {
            watchlistModel.insert(0, item)
        }
        let ids = { ...window.watchlistIds }
        if (ids[item.imdbId]) delete ids[item.imdbId]
        else ids[item.imdbId] = true
        window.watchlistIds = ids
        saveWatchlist()
    }

    function removeFromWatchHistory(idx) {
        if (idx < 0 || idx >= watchHistoryModel.count) return
        watchHistoryModel.remove(idx)
        saveWatchHistory()
    }

    function clearWatchHistory() {
        watchHistoryModel.clear()
        saveWatchHistory()
    }

    function clearSearchHistory() {
        searchHistoryModel.clear()
        saveHistory()
    }

    // --- FILTER HELPERS (genre / year / rating) ---
    function itemPassesFilters(item) {
        if (window.activeGenreFilters.length > 0) {
            let g = item.genres || []
            let hit = false
            for (let i = 0; i < window.activeGenreFilters.length; i++) { if (g.indexOf(window.activeGenreFilters[i]) !== -1) { hit = true; break } }
            if (!hit) return false
        }
        let yr = parseInt(item.year || 0) || 0
        if (yr > 0) {
            if (yr < window.minYearFilter || yr > window.maxYearFilter) return false
        }
        let rating = parseFloat(item.rating || 0) || 0
        if (rating < window.minRatingFilter) return false
        return true
    }

    function resetFilters() {
        window.activeGenreFilters = []
        window.minYearFilter = 1950
        window.maxYearFilter = 2026
        window.minRatingFilter = 0
        applyFiltersAndPopulate()
        applyFiltersToPopular()
    }

    function toggleGenreFilter(genre) {
        let list = window.activeGenreFilters.slice()
        let idx = list.indexOf(genre)
        if (idx !== -1) list.splice(idx, 1); else list.push(genre)
        window.activeGenreFilters = list
        applyFiltersAndPopulate()
        applyFiltersToPopular()
    }

    function saveSourcePref(imdbId, sourceName) {
        let prefs = window.sourcePrefs
        prefs[imdbId] = sourceName
        window.sourcePrefs = prefs
        saveJsonToCache("qs_source_prefs.json", prefs)
    }

    // --- SOURCE MODEL ---
    ListModel {
        id: sourceModel
        ListElement { name: "VidSrc.net";    urlMovie: "https://vidsrc.net/embed/movie/%1";                               urlTv: "https://vidsrc.net/embed/tv/%1/%2/%3";                            status: "pending" }
        ListElement { name: "VidLink";       urlMovie: "https://vidlink.pro/movie/%1?autoplay=1";                         urlTv: "https://vidlink.pro/tv/%1/%2/%3?autoplay=1";                      status: "pending" }
        ListElement { name: "VidSrc.pro";    urlMovie: "https://vidsrc.pro/embed/movie/%1";                               urlTv: "https://vidsrc.pro/embed/tv/%1/%2/%3";                            status: "pending" }
        ListElement { name: "VidSrc.in";     urlMovie: "https://vidsrc.in/embed/movie/%1";                                urlTv: "https://vidsrc.in/embed/tv/%1/%2/%3";                             status: "pending" }
        ListElement { name: "VidSrc.cc";     urlMovie: "https://vidsrc.cc/v2/embed/movie/%1?autoPlay=true";               urlTv: "https://vidsrc.cc/v2/embed/tv/%1/%2/%3?autoPlay=true";            status: "pending" }
        ListElement { name: "Embed.su";      urlMovie: "https://embed.su/embed/movie/%1";                                 urlTv: "https://embed.su/embed/tv/%1/%2/%3";                              status: "pending" }
        ListElement { name: "SmashyStream";  urlMovie: "https://player.smashy.stream/movie/%1";                           urlTv: "https://player.smashy.stream/tv/%1?s=%2&e=%3";                    status: "pending" }
        ListElement { name: "AutoEmbed";     urlMovie: "https://autoembed.to/movie/imdb/%1";                              urlTv: "https://autoembed.to/tv/imdb/%1-%2-%3";                           status: "pending" }
        ListElement { name: "2Embed";        urlMovie: "https://www.2embed.cc/embed/%1";                                  urlTv: "https://www.2embed.cc/embedtv/%1&s=%2&e=%3";                      status: "pending" }
        ListElement { name: "MultiEmbed";    urlMovie: "https://multiembed.mov/directstream.php?video_id=%1";             urlTv: "https://multiembed.mov/directstream.php?video_id=%1&s=%2&e=%3";  status: "pending" }
    }

    // --- ANIMATIONS & FOCUS ---
    property real introPhase: 0
    NumberAnimation on introPhase {
        id: introPhaseAnim
        from: 0; to: 1; duration: 800; easing.type: Easing.OutQuart; running: true
    }

    Timer {
        id: focusTimer
        interval: 50; running: true; repeat: false
        onTriggered: {
            if (window.currentView === "search") searchInput.forceActiveFocus()
            else window.forceActiveFocus()
        }
    }

    Timer {
        id: scrollToTopTimer
        interval: 80; running: false; repeat: false
        onTriggered: {
            movieGrid.positionViewAtBeginning()
            tvGrid.positionViewAtBeginning()
            searchGrid.positionViewAtBeginning()
        }
    }

    Component.onCompleted: {
        readHistoryProc.running = true
        readWatchHistoryProc.running = true
        readSourcePrefsProc.running = true
        window.isFetchingMovies = true
        window.isFetchingTv = true
        readTrendingCacheProc.running = true
        readUiStateProc.running = true
    }

    Connections {
        target: window
        function onVisibleChanged() {
            if (window.visible) {
                introPhaseAnim.restart()
                if (!window.isSourceModalOpen && window.currentView === "search") {
                    focusTimer.restart()
                    scrollToTopTimer.restart()
                } else if (window.currentView === "series") {
                    seriesFocusRestoreTimer.restart()
                }
                if (searchHistoryModel.count === 0) readHistoryProc.running = true
                if (watchHistoryModel.count === 0) readWatchHistoryProc.running = true
                if (watchlistModel.count === 0) readWatchlistProc.running = true
                if (!window.trendingMoviesLoaded) fetchTrending("movie")
                if (!window.trendingTvLoaded) fetchTrending("series")
                if (searchInput.text !== "") doSearch(searchInput.text)
                if (window.currentView === "series" && window.selectedImdbId !== "" && episodeModel.count === 0) {
                    fetchSeriesData(window.selectedImdbId, window.currentSeason, "", "", true)
                }
            } else {
                saveUiState()
            }
        }
    }

    Keys.onPressed: (event) => {
        if (window.isSourceModalOpen) {
            if (event.key === Qt.Key_Escape) { window.closeSourceModal(); event.accepted = true }
        } else if (window.currentView === "series") {
            if (event.key === Qt.Key_Escape) {
                window.currentView = "search"
                searchInput.forceActiveFocus()
                event.accepted = true
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                let sCount = seasonModel.count
                if (sCount > 0) {
                    let idx = -1
                    for (let i = 0; i < sCount; i++) { if (seasonModel.get(i).seasonNum === window.currentSeason) { idx = i; break } }
                    if (idx !== -1) {
                        let step = event.key === Qt.Key_Tab ? 1 : -1
                        window.currentSeason = seasonModel.get((idx + step + sCount) % sCount).seasonNum
                        updateEpisodes(window.currentSeason)
                    }
                }
                event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                if (epList.currentIndex < epList.count - 1) epList.currentIndex++; event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                if (epList.currentIndex > 0) epList.currentIndex--; event.accepted = true
            } else if (event.key === Qt.Key_Return) {
                let ep = episodeModel.get(epList.currentIndex)
                if (ep) startSourceCheck("tv", window.selectedImdbId, window.selectedTitle, window.selectedPoster, window.currentSeason, ep.epNum)
                event.accepted = true
            }
        } else if (event.key === Qt.Key_Escape) {
            saveUiState()
            Quickshell.execDetached(["bash", Quickshell.env("HOME") + "/.config/hypr/scripts/qs_manager.sh", "close"])
            event.accepted = true
        }
    }

    property bool isKeyboardNav: false
    // Previously auto-cleared after 500ms via a Timer, which silently broke
    // Enter-to-play if the user paused before pressing Enter. isKeyboardNav is
    // now only cleared by actual mouse movement (see GridView delegates' onEntered).
    Timer { id: keyboardNavTimer; interval: 500; repeat: false }

    ListModel { id: searchHistoryModel }
    ListModel { id: watchHistoryModel }
    ListModel { id: watchlistModel }
    ListModel { id: cachedTrendingMovies }
    ListModel { id: cachedTrendingTv }
    ListModel { id: searchResults }
    ListModel { id: seasonModel }
    ListModel { id: episodeModel }

    function addToWatchHistory(item) {
        for (let i = 0; i < watchHistoryModel.count; i++) {
            if (watchHistoryModel.get(i).imdbId === item.imdbId) {
                watchHistoryModel.remove(i)
                break
            }
        }
        watchHistoryModel.insert(0, item)
        if (watchHistoryModel.count > 15) watchHistoryModel.remove(15)
        saveWatchHistory()
    }

    function addSearchHistory(query) {
        if (query.trim() === "") return
        for (let i = 0; i < searchHistoryModel.count; i++) {
            if (searchHistoryModel.get(i).query.toLowerCase() === query.toLowerCase()) {
                searchHistoryModel.remove(i)
                break
            }
        }
        searchHistoryModel.insert(0, { query: query.trim() })
        if (searchHistoryModel.count > 10) searchHistoryModel.remove(10)
        saveHistory()
    }

    // ==========================================
    // SOURCE CHECKING SYSTEM
    // ==========================================
    property bool isSourceModalOpen: false
    property int currentCheckIndex: 0
    property var pendingMedia: ({})
    property string checkingState: "idle"
    property string foundSourceName: ""
    property string sourceSearchQuery: ""
    // Multiple sources are probed at once now (see sourceCheckConcurrency),
    // so we track them in a map of index -> in-flight XHR instead of a
    // single "active" one.
    property var activeXhrs: ({})
    readonly property int sourceCheckConcurrency: 3
    readonly property var errorPagePatterns: [
        "404", "not found", "no results", "video not found", "media not found",
        "content not found", "page not found", "error 404", "does not exist"
    ]

    function buildSourceUrl(srcIndex) {
        let src = sourceModel.get(srcIndex)
        let m = pendingMedia
        if (m.type === "movie") return src.urlMovie.arg(m.imdbId)
        return src.urlTv.arg(m.imdbId).arg(m.season).arg(m.ep)
    }

    function buildSourceOrder() {
        let order = []
        let imdbId = pendingMedia.imdbId
        let preferred = window.sourcePrefs[imdbId] || null
        let prefIdx = -1
        if (preferred) {
            for (let i = 0; i < sourceModel.count; i++) {
                if (sourceModel.get(i).name === preferred) { prefIdx = i; break }
            }
        }
        if (prefIdx !== -1) order.push(prefIdx)
        for (let i = 0; i < sourceModel.count; i++) { if (i !== prefIdx) order.push(i) }
        return order
    }

    property var sourceCheckOrder: []
    property int sourceCheckStep: 0 // pointer to the next not-yet-dispatched entry in sourceCheckOrder

    function startSourceCheck(type, imdbId, title, poster, season, ep) {
        pendingMedia = { type: type, imdbId: imdbId, title: title, poster: poster, season: season, ep: ep }
        for (let i = 0; i < sourceModel.count; i++) sourceModel.setProperty(i, "status", "pending")
        addToWatchHistory({ imdbId: imdbId, title: title, poster: poster, type: type })
        window.sourceCheckOrder = buildSourceOrder()
        window.sourceCheckStep = 0
        window.currentCheckIndex = window.sourceCheckOrder[0]
        window.foundSourceName = ""
        window.sourceSearchQuery = ""
        window.isSourceModalOpen = true
        window.checkingState = "checking"
        window.activeXhrs = {}
        if (sourceListUI) sourceListUI.positionViewAtBeginning()
        fillCheckSlots()
        saveUiState()
    }

    // Aborts every in-flight probe. Any row still stuck on "checking" (i.e.
    // it was interrupted, not actually determined to have failed) gets
    // reverted to "pending" so it can still be retried later — except the
    // one we're keeping (e.g. the source that just succeeded).
    function abortAllChecks(keepIdx) {
        for (let k in window.activeXhrs) {
            try { window.activeXhrs[k].abort() } catch(e) {}
        }
        window.activeXhrs = {}
        for (let i = 0; i < sourceModel.count; i++) {
            if (sourceModel.get(i).status === "checking" && i !== keepIdx) {
                sourceModel.setProperty(i, "status", "pending")
            }
        }
    }

    function closeSourceModal() {
        abortAllChecks(-1)
        window.isSourceModalOpen = false
        window.checkingState = "idle"
        window.sourceSearchQuery = ""
        if (window.currentView === "series") window.forceActiveFocus()
        else searchInput.forceActiveFocus()
        saveUiState()
    }

    // Re-runs the background check from scratch (e.g. after the user has
    // exhausted the list and wants a fresh pass). Playing a source no longer
    // depends on this finishing, or on it succeeding at all.
    function recheckSources() {
        abortAllChecks(-1)
        for (let i = 0; i < sourceModel.count; i++) sourceModel.setProperty(i, "status", "pending")
        window.sourceCheckOrder = buildSourceOrder()
        window.sourceCheckStep = 0
        window.checkingState = "checking"
        fillCheckSlots()
    }

    // Tops up the in-flight batch up to sourceCheckConcurrency at a time —
    // several sources get probed in parallel instead of one by one. Checking
    // keeps going across every source (it no longer stops at the first
    // success) so the list ends up with a full picture of what's currently
    // reachable, letting the user make an informed choice rather than being
    // steered toward whichever source happened to respond first.
    function fillCheckSlots() {
        if (!window.isSourceModalOpen || window.checkingState !== "checking") return
        while (Object.keys(window.activeXhrs).length < window.sourceCheckConcurrency &&
               window.sourceCheckStep < window.sourceCheckOrder.length) {
            let idx = window.sourceCheckOrder[window.sourceCheckStep]
            window.sourceCheckStep++
            dispatchCheck(idx)
        }
        if (Object.keys(window.activeXhrs).length === 0 && window.sourceCheckStep >= window.sourceCheckOrder.length) {
            let anySuccess = false
            for (let i = 0; i < sourceModel.count; i++) {
                if (sourceModel.get(i).status === "success") { anySuccess = true; break }
            }
            window.checkingState = anySuccess ? "idle" : "failed_all"
        }
    }

    function dispatchCheck(idx) {
        sourceModel.setProperty(idx, "status", "checking")

        let url = buildSourceUrl(idx)
        let xhr = new XMLHttpRequest()
        window.activeXhrs[idx] = xhr

        function slotDone() {
            delete window.activeXhrs[idx]
            fillCheckSlots()
        }

        xhr.open("GET", url, true)
        xhr.timeout = 6000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || !window.isSourceModalOpen ||
                window.checkingState !== "checking" || !(idx in window.activeXhrs)) return
            let code = xhr.status
            let body = xhr.responseText ? xhr.responseText.toLowerCase() : ""

            if (code === 404 || code === 410) {
                sourceModel.setProperty(idx, "status", "failed")
                slotDone()
                return
            }
            if (code === 200 && body.length < 3000) {
                let looksLikeError = false
                for (let i = 0; i < window.errorPagePatterns.length; i++) {
                    if (body.indexOf(window.errorPagePatterns[i]) !== -1) {
                        looksLikeError = true
                        break
                    }
                }
                if (looksLikeError) {
                    sourceModel.setProperty(idx, "status", "failed")
                    slotDone()
                    return
                }
            }
            let isLive = (code === 0) || (code >= 200 && code < 400) || code === 401 || code === 403
            if (isLive) {
                sourceModel.setProperty(idx, "status", "success")
                window.foundSourceName = sourceModel.get(idx).name
                saveUiState()
            } else {
                sourceModel.setProperty(idx, "status", "failed")
            }
            slotDone()
        }
        xhr.ontimeout = function() {
            if (!window.isSourceModalOpen || window.checkingState !== "checking" || !(idx in window.activeXhrs)) return
            sourceModel.setProperty(idx, "status", "failed")
            slotDone()
        }
        xhr.onerror = function() {
            if (!window.isSourceModalOpen || window.checkingState !== "checking" || !(idx in window.activeXhrs)) return
            // Network layer errors are common for these embeds even when the
            // stream itself is fine (CORS, redirects XHR can't follow) — treat
            // as a soft success rather than a hard failure.
            sourceModel.setProperty(idx, "status", "success")
            window.foundSourceName = sourceModel.get(idx).name
            saveUiState()
            slotDone()
        }
        xhr.send()
    }

    // The one and only way anything ever launches: the user tapping a row,
    // whenever they want, whatever its check status. No gate, no separate
    // "confirm" step — this is the entire interaction.
    function selectSourceManually(idx) {
        let url = buildSourceUrl(idx)
        window.currentCheckIndex = idx
        Quickshell.execDetached(["xdg-open", url])
        saveUiState()
    }

    function copyStreamLink(idx) {
        let url = buildSourceUrl(idx)
        Quickshell.execDetached(["bash", "-c", "printf '%s' \"$1\" | wl-copy", "_", url])
        window.currentCheckIndex = idx
        window.linkCopiedToast = true
        toastResetTimer.restart()
    }
    property bool linkCopiedToast: false
    Timer { id: toastResetTimer; interval: 1600; repeat: false; onTriggered: window.linkCopiedToast = false }

    // --- DATA FETCHING & FILTERING ---
    function fetchTrending(typeStr) {
        let isMovie = typeStr === "movie"
        if (isMovie) window.isFetchingMovies = true; else window.isFetchingTv = true
        
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://v3-cinemeta.strem.io/catalog/" + typeStr + "/top.json")
        xhr.onerror = function() { if (isMovie) window.isFetchingMovies = false; else window.isFetchingTv = false }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (isMovie) window.isFetchingMovies = false; else window.isFetchingTv = false
            if (xhr.status === 200) {
                try {
                    let res = JSON.parse(xhr.responseText)
                    if (res && res.metas) {
                        let rawItems = []
                        let targetModel = isMovie ? cachedTrendingMovies : cachedTrendingTv
                        targetModel.clear()
                        for (let i = 0; i < res.metas.length; i++) {
                            let item = res.metas[i]
                            if (!item.id || !item.poster) continue
                            let entry = {
                                imdbId: item.id,
                                title: item.name || "Unknown",
                                poster: item.poster || item.posterShape || item.background || item.logo || "",
                                type: isMovie ? "movie" : "tv",
                                year: item.releaseInfo || "N/A",
                                rating: item.imdbRating || 0,
                                genres: item.genres || item.genre || [],
                                popularity: i
                            }
                            rawItems.push(entry)
                            targetModel.append(entry)
                        }
                        if (isMovie) { window.rawTrendingMovies = rawItems; window.trendingMoviesLastFetch = Date.now(); window.trendingMoviesLoaded = true } 
                        else { window.rawTrendingTv = rawItems; window.trendingTvLastFetch = Date.now(); window.trendingTvLoaded = true }
                        saveTrendingCache()
                    }
                } catch(e) {}
            }
        }
        xhr.send()
    }

    function getSortValue(item, field) {
        if (field === "year") return parseInt(item.year || item.releaseInfo || 0) || 0
        if (field === "title") return (item.title || item.name || "").toString()
        if (field === "rating") return parseFloat(item.rating || item.imdbRating || 0) || 0
        return 0
    }

    function sortItems(items) {
        let mode = window.filterSort
        if (mode === "Year (Newest)") items.sort((a, b) => getSortValue(b, "year") - getSortValue(a, "year"))
        else if (mode === "Year (Oldest)") items.sort((a, b) => getSortValue(a, "year") - getSortValue(b, "year"))
        else if (mode === "Title (A-Z)") items.sort((a, b) => getSortValue(a, "title").localeCompare(getSortValue(b, "title")))
        else if (mode === "Title (Z-A)") items.sort((a, b) => getSortValue(b, "title").localeCompare(getSortValue(a, "title")))
        else if (mode === "Rating (Best)") items.sort((a, b) => getSortValue(b, "rating") - getSortValue(a, "rating"))
        else if (mode === "Rating (Worst)") items.sort((a, b) => getSortValue(a, "rating") - getSortValue(b, "rating"))
        return items
    }

    function applyFiltersToPopular() {
        let rawMovies = sortItems(window.rawTrendingMovies.slice().filter(itemPassesFilters))
        let rawTv = sortItems(window.rawTrendingTv.slice().filter(itemPassesFilters))
        cachedTrendingMovies.clear(); for (let i = 0; i < rawMovies.length; i++) cachedTrendingMovies.append(rawMovies[i])
        cachedTrendingTv.clear(); for (let i = 0; i < rawTv.length; i++) cachedTrendingTv.append(rawTv[i])
        movieGrid.positionViewAtBeginning()
        tvGrid.positionViewAtBeginning()
    }

    // Union of every genre seen across whichever trending pool is active —
    // feeds the genre filter chips so they only ever show real options.
    function availableGenres() {
        let pool = window.mediaType === "movie" ? window.rawTrendingMovies : window.rawTrendingTv
        let seen = {}
        let out = []
        for (let i = 0; i < pool.length; i++) {
            let g = pool[i].genres || []
            for (let j = 0; j < g.length; j++) {
                if (!seen[g[j]]) { seen[g[j]] = true; out.push(g[j]) }
            }
        }
        out.sort()
        return out
    }

    function applyFiltersAndPopulate() {
        window.isKeyboardNav = false
        searchResults.clear()
        let items = sortItems(window.currentFetchResults.slice())
        for (let i = 0; i < items.length; i++) {
            let item = items[i]
            if (!item.id) continue
            let normalized = {
                imdbId: item.id, title: item.name || "Unknown", poster: item.poster || "",
                type: item.type === "series" ? "tv" : "movie", year: item.releaseInfo || "N/A", rating: item.imdbRating || 0,
                genres: item.genres || item.genre || []
            }
            if (!itemPassesFilters(normalized)) continue
            searchResults.append(normalized)
        }
        Qt.callLater(function() {
            if (searchGrid && searchGrid.count > 0) searchGrid.currentIndex = 0
            if (movieGrid && movieGrid.count > 0) movieGrid.currentIndex = 0
            if (tvGrid && tvGrid.count > 0) tvGrid.currentIndex = 0
        })
    }

    function doSearch(query) {
        let q = encodeURIComponent(query.trim())
        let expectedType = window.mediaType
        let typeStr = expectedType === "movie" ? "movie" : "series"
        if (q === "") { searchResults.clear(); window.isSearchingNetwork = false; return }
        addSearchHistory(query)
        window.isSearchingNetwork = true
        searchResults.clear()
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://v3-cinemeta.strem.io/catalog/" + typeStr + "/top/search=" + q + ".json")
        xhr.onerror = function() { window.isSearchingNetwork = false }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (window.mediaType === expectedType) {
                window.isSearchingNetwork = false
                if (xhr.status === 200) {
                    try {
                        let res = JSON.parse(xhr.responseText)
                        if (res && res.metas) {
                            window.currentFetchResults = res.metas
                            applyFiltersAndPopulate()
                            enrichSearchPosters(res.metas, typeStr)
                        }
                    } catch(e) {}
                }
            }
        }
        xhr.send()
    }

    function enrichSearchPosters(metas, typeStr) {
        for (let i = 0; i < metas.length; i++) {
            let item = metas[i]
            if (item.poster && item.poster !== "") continue
            let capturedImdbId = item.id
            ;(function(cImdbId) {
                var xhr2 = new XMLHttpRequest()
                xhr2.open("GET", "https://v3-cinemeta.strem.io/meta/" + typeStr + "/" + cImdbId + ".json")
                xhr2.onreadystatechange = function() {
                    if (xhr2.readyState !== XMLHttpRequest.DONE) return
                    if (xhr2.status === 200) {
                        try {
                            let res2 = JSON.parse(xhr2.responseText)
                            if (res2 && res2.meta) {
                                let poster = res2.meta.poster || res2.meta.background || ""
                                if (poster !== "") {
                                    for (let j = 0; j < searchResults.count; j++) {
                                        if (searchResults.get(j).imdbId === cImdbId) {
                                            searchResults.setProperty(j, "poster", poster)
                                            break
                                        }
                                    }
                                    return
                                }
                            }
                        } catch(e) {}
                    }
                    fetchPosterFallback(cImdbId, typeStr)
                }
                xhr2.send()
            })(capturedImdbId)
        }
    }

    function fetchPosterFallback(imdbId, typeStr) {
        let rpdbUrl = "https://api.ratingposterdb.com/imdb/poster-default/" + imdbId + ".jpg"
        var xhrCheck = new XMLHttpRequest()
        xhrCheck.open("HEAD", rpdbUrl, true)
        xhrCheck.timeout = 5000
        xhrCheck.onreadystatechange = function() {
            if (xhrCheck.readyState !== XMLHttpRequest.DONE) return
            if (xhrCheck.status === 200) {
                for (let j = 0; j < searchResults.count; j++) {
                    if (searchResults.get(j).imdbId === imdbId) {
                        searchResults.setProperty(j, "poster", rpdbUrl)
                        break
                    }
                }
            }
        }
        xhrCheck.onerror = function() { /* silently fail — delegate shows title fallback */ }
        xhrCheck.send()
    }

    function fetchAndUpdatePoster(imdbId, typeStr, targetModel) {
        var xhr = new XMLHttpRequest()
        let metaType = typeStr === "tv" ? "series" : "movie"
        xhr.open("GET", "https://v3-cinemeta.strem.io/meta/" + metaType + "/" + imdbId + ".json")
        xhr.timeout = 6000
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            let posterFound = ""
            if (xhr.status === 200) {
                try {
                    let res = JSON.parse(xhr.responseText)
                    if (res && res.meta) posterFound = res.meta.poster || res.meta.background || ""
                } catch(e) {}
            }
            if (posterFound !== "") {
                for (let j = 0; j < targetModel.count; j++) {
                    if (targetModel.get(j).imdbId === imdbId) {
                        targetModel.setProperty(j, "poster", posterFound)
                        break
                    }
                }
            } else {
                fetchPosterFallback(imdbId, metaType)
            }
        }
        xhr.onerror = function() { fetchPosterFallback(imdbId, metaType) }
        xhr.send()
    }

    function fetchSeriesData(imdbId, targetSeason, title, poster, isReload) {
        if (!isReload) {
            window.selectedImdbId = imdbId
            window.selectedTitle = title
            window.selectedPoster = poster
            window.selectedDescription = ""
            window.selectedGenres = []
            window.selectedCast = []
            window.selectedTrailerYtId = ""
            window.selectedRatingLabel = ""
            window.selectedBackdrop = ""
            window.selectedYear = ""
            window.selectedRuntime = ""
            window.selectedDirector = ""
            window.similarTitles = []
            window.isMovieDetail = false
            window.currentView = "series"
            window.forceActiveFocus()
        }
        window.isLoadingSeries = true
        seasonModel.clear()
        episodeModel.clear()

        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://v3-cinemeta.strem.io/meta/series/" + imdbId + ".json")
        xhr.onerror = function() { 
            window.isLoadingSeries = false
            if (isReload && window.pendingSeriesFocusRestore) seriesFocusRestoreTimer.restart()
        }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            window.isLoadingSeries = false
            if (xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    if (res && res.meta) {
                        if (!isReload || !window.selectedDescription) window.selectedDescription = res.meta.description || res.meta.synopsis || ""
                        if ((!window.selectedPoster || window.selectedPoster === "") && res.meta.poster) window.selectedPoster = res.meta.poster
                        if (!isReload) applyDetailMeta(res.meta)
                        
                        if (res.meta.videos) {
                            let seasonsMap = {}
                            for (let i = 0; i < res.meta.videos.length; i++) {
                                let v = res.meta.videos[i]
                                if (v.season === 0) continue
                                if (!seasonsMap[v.season]) seasonsMap[v.season] = []
                                let epTitle = v.name || v.title || null
                                if (epTitle && /^(episode\s*\d+|s\d+e\d+|ep\.?\s*\d+)$/i.test(epTitle.toLowerCase().trim())) epTitle = null
                                seasonsMap[v.season].push({
                                    ep: v.episode,
                                    title: epTitle || ("Episode " + v.episode),
                                    hasRealTitle: epTitle !== null
                                })
                            }
                            let seasonKeys = Object.keys(seasonsMap).map(Number).sort((a, b) => a - b)
                            for (let i = 0; i < seasonKeys.length; i++) seasonModel.append({ seasonNum: seasonKeys[i] })
                            window.seriesDataMap = seasonsMap
                            
                            let newTargetSeason = (isReload && seasonsMap[targetSeason]) ? targetSeason : (seasonKeys[0] || 1)
                            window.currentSeason = newTargetSeason
                            updateEpisodes(newTargetSeason)
                        }
                    }
                } catch(e) {}
            }
            if (isReload && window.pendingSeriesFocusRestore) seriesFocusRestoreTimer.restart()
            if (!isReload) saveUiState()
        }
        xhr.send()
    }

    function loadSeriesDetails(imdbId, title, poster) {
        fetchSeriesData(imdbId, 1, title, poster, false)
    }

    // Movies now land on the same detail view as TV shows instead of jumping
    // straight into source-checking, so there's a place to show the trailer,
    // cast, and similar titles before committing to a source.
    function loadMovieDetails(imdbId, title, poster) {
        window.selectedImdbId = imdbId
        window.selectedTitle = title
        window.selectedPoster = poster
        window.selectedDescription = ""
        window.selectedGenres = []
        window.selectedCast = []
        window.selectedTrailerYtId = ""
        window.selectedRatingLabel = ""
        window.selectedRTRating = ""
        window.selectedMetacriticRating = ""
        window.selectedBackdrop = ""
        window.selectedYear = ""
        window.selectedRuntime = ""
        window.selectedDirector = ""
        window.similarTitles = []
        window.isMovieDetail = true
        window.mediaType = "movie"
        window.currentView = "series"
        window.forceActiveFocus()
        window.isLoadingSeries = true

        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://v3-cinemeta.strem.io/meta/movie/" + imdbId + ".json")
        xhr.onerror = function() { window.isLoadingSeries = false }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            window.isLoadingSeries = false
            if (xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText)
                    if (res && res.meta) {
                        window.selectedDescription = res.meta.description || res.meta.synopsis || ""
                        if ((!window.selectedPoster || window.selectedPoster === "") && res.meta.poster) window.selectedPoster = res.meta.poster
                        applyDetailMeta(res.meta)
                    }
                } catch(e) {}
            }
            saveUiState()
        }
        xhr.send()
    }

    // Shared by both the movie and series detail fetches: genre tags, a
    // handful of cast names, trailer id, and the rating label. Also kicks
    // off the "similar titles" heuristic once genres are known.
    function applyDetailMeta(meta) {
        window.selectedGenres = meta.genre || meta.genres || []
        window.selectedRatingLabel = meta.imdbRating ? ("★ " + meta.imdbRating) : ""
        window.selectedBackdrop = meta.background || meta.fanart || ""
        window.selectedYear = (meta.releaseInfo || meta.year || "").toString()
        window.selectedRuntime = meta.runtime ? meta.runtime.toString().replace(/[^0-9]/g, "") + " min" : ""
        if (meta.director && meta.director.length) window.selectedDirector = Array.isArray(meta.director) ? meta.director.slice(0, 2).join(", ") : meta.director
        else window.selectedDirector = ""
        let castArr = []
        if (meta.cast && meta.cast.length) castArr = meta.cast.slice(0, 6)
        else if (meta.credits && meta.credits.cast) castArr = meta.credits.cast.slice(0, 6).map(c => c.name || c)
        window.selectedCast = castArr
        let ytId = ""
        if (meta.trailers && meta.trailers.length > 0) {
            for (let i = 0; i < meta.trailers.length; i++) {
                if (meta.trailers[i].source) { ytId = meta.trailers[i].source; break }
            }
        } else if (meta.trailerStreams && meta.trailerStreams.length > 0) {
            ytId = meta.trailerStreams[0].ytId || ""
        }
        window.selectedTrailerYtId = ytId
        window.selectedRTRating = ""
        window.selectedMetacriticRating = ""
        if (window.omdbApiKey !== "") fetchExtraRatings(window.selectedImdbId)
        computeSimilarTitles()
    }

    // Optional: only fires if an OMDb API key has been set above. Adds
    // Rotten Tomatoes / Metacritic alongside the IMDb score already shown.
    function fetchExtraRatings(imdbId) {
        let capturedId = imdbId
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://www.omdbapi.com/?i=" + capturedId + "&apikey=" + window.omdbApiKey)
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || xhr.status !== 200) return
            if (window.selectedImdbId !== capturedId) return // user navigated away meanwhile
            try {
                let res = JSON.parse(xhr.responseText)
                if (res && res.Ratings) {
                    for (let i = 0; i < res.Ratings.length; i++) {
                        if (res.Ratings[i].Source === "Rotten Tomatoes") window.selectedRTRating = res.Ratings[i].Value
                        if (res.Ratings[i].Source === "Metacritic") window.selectedMetacriticRating = res.Ratings[i].Value
                    }
                }
            } catch(e) {}
        }
        xhr.send()
    }

    // Cheap "similar titles" heuristic: rank cached trending items of the
    // same media type by how many genres they share, no extra network call.
    function computeSimilarTitles() {
        let pool = window.isMovieDetail ? window.rawTrendingMovies : window.rawTrendingTv
        if (!pool || pool.length === 0) { window.similarTitles = []; return }
        let mine = window.selectedGenres || []
        let scored = []
        for (let i = 0; i < pool.length; i++) {
            let item = pool[i]
            if (item.imdbId === window.selectedImdbId) continue
            let g = item.genres || []
            let overlap = 0
            for (let j = 0; j < g.length; j++) if (mine.indexOf(g[j]) !== -1) overlap++
            if (mine.length === 0 || overlap > 0) scored.push({ item: item, overlap: overlap })
        }
        scored.sort((a, b) => (b.overlap - a.overlap) || ((b.item.rating || 0) - (a.item.rating || 0)))
        window.similarTitles = scored.slice(0, 16).map(s => s.item)
    }

    function openTrailer() {
        if (window.selectedTrailerYtId === "") return
        Quickshell.execDetached(["xdg-open", "https://www.youtube.com/watch?v=" + window.selectedTrailerYtId])
    }

    function updateEpisodes(seasonNum) {
        window.seasonSwitching = true
        seasonContentSwapTimer.targetSeason = seasonNum
        seasonContentSwapTimer.restart()
    }

    Timer {
        id: seasonContentSwapTimer
        property int targetSeason: 1
        interval: 220
        repeat: false
        onTriggered: {
            episodeModel.clear()
            let eps = window.seriesDataMap[targetSeason]
            if (eps) {
                eps.sort((a, b) => a.ep - b.ep)
                for (let i = 0; i < eps.length; i++) {
                    episodeModel.append({ epNum: eps[i].ep, epTitle: eps[i].title, hasRealTitle: eps[i].hasRealTitle || false })
                }
            }
            epList.currentIndex = 0
            epList.positionViewAtBeginning()
            seasonFadeInTimer.restart()
        }
    }

    Timer { id: seasonFadeInTimer; interval: 30; repeat: false; onTriggered: window.seasonSwitching = false }

    function getActiveGrid() {
        if (window.isSearchMode) return searchGrid
        if (window.mediaType === "movie") return movieGrid
        return tvGrid
    }

    // --- SHARED STYLES ---
    component CustomComboBox: ComboBox {
        id: control
        font.family: window.fontUI; font.pixelSize: window.s(14)
        delegate: ItemDelegate {
            width: control.width; height: window.s(36)
            contentItem: Text { text: modelData || model.name; color: window.text; font: control.font; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { color: control.highlightedIndex === index ? window.surface1 : "transparent"; radius: window.s(10) }
        }
        indicator: Canvas {
            id: canvas
            x: control.width - width - control.rightPadding; y: control.topPadding + (control.availableHeight - height) / 2
            width: 12; height: 8; contextType: "2d"
            Connections { target: control; function onPressedChanged() { canvas.requestPaint() } }
            onPaint: { var ctx = canvas.getContext("2d"); ctx.reset(); ctx.moveTo(0, 0); ctx.lineTo(width, 0); ctx.lineTo(width / 2, height); ctx.fillStyle = window.subtext0; ctx.fill() }
        }
        contentItem: Text { leftPadding: window.s(10); rightPadding: control.indicator.width + control.spacing; text: control.currentText; font: control.font; color: window.text; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        background: Rectangle { implicitWidth: window.s(180); implicitHeight: window.s(36); color: window.surface0; border.color: control.activeFocus ? window.surface2 : window.surface1; border.width: control.visualFocus ? 2 : 1; radius: height / 2 }
        popup: Popup {
            y: control.height + window.s(4); width: control.width; implicitHeight: contentItem.implicitHeight; padding: window.s(4)
            contentItem: ListView { clip: true; implicitHeight: contentHeight; model: control.popup.visible ? control.delegateModel : null; currentIndex: control.highlightedIndex }
            background: Rectangle { color: window.crust; border.color: window.surface1; radius: window.s(14) }
        }
    }

    component PosterDelegate: Rectangle {
        id: posterCard
        width: window.s(120); height: width * 1.5
        radius: window.rMD(); color: window.crust; clip: true
        // When true (Continue Watching row), shows a small × in the corner
        // to drop that one item out of history without touching the rest.
        property bool removable: false
        signal removeRequested()
        readonly property color accent: model.type === "tv" ? window.blue : window.mauve
        readonly property bool posterReady: posterImg.status === Image.Ready
        scale: posterMouse.containsMouse ? 1.045 : 1.0
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: window.shadowColor
            shadowBlur: posterMouse.containsMouse ? 0.7 : 0.35
            shadowVerticalOffset: posterMouse.containsMouse ? 6 : 2
            shadowOpacity: posterMouse.containsMouse ? 0.4 : 0.2
            Behavior on shadowBlur { NumberAnimation { duration: 220 } }
            Behavior on shadowVerticalOffset { NumberAnimation { duration: 220 } }
            Behavior on shadowOpacity { NumberAnimation { duration: 220 } }
        }
        Image {
            id: posterImg
            anchors.fill: parent
            source: model.poster !== "" ? model.poster : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            smooth: true
            cache: true
            sourceSize.width: window.s(240)
            sourceSize.height: window.s(360)
            visible: status === Image.Ready
        }
        Rectangle {
            anchors.fill: parent
            color: window.surface0
            visible: model.poster === "" || posterImg.status === Image.Error || posterImg.status === Image.Null
            radius: window.rMD()
            Column {
                anchors.centerIn: parent
                width: parent.width - window.s(10)
                spacing: window.s(6)
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: model.type === "tv" ? "📺" : "🎬"
                    font.pixelSize: window.s(22)
                }
                Text {
                    width: parent.width
                    text: model.title || "Unknown"
                    color: window.subtext0
                    font.family: window.fontUI
                    font.pixelSize: window.s(11)
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }
            }
        }
        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: parent.height * 0.5
            visible: posterCard.posterReady
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
            }
        }
        Text {
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.margins: window.s(10)
            visible: posterCard.posterReady
            text: model.title || "Unknown"
            color: "#ffffff"; font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(12)
            wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; lineHeight: 1.15
        }
        Rectangle {
            anchors.top: parent.top; anchors.right: parent.right; anchors.margins: window.s(7)
            visible: !posterCard.removable && (posterCard.posterReady) && (heartMouse.containsMouse || window.isInWatchlist(model.imdbId))
            width: window.s(22); height: window.s(22); radius: window.s(11)
            color: Qt.rgba(0.08, 0.08, 0.09, 0.55)
            Text {
                anchors.centerIn: parent
                text: window.isInWatchlist(model.imdbId) ? "♥" : "♡"
                color: window.isInWatchlist(model.imdbId) ? window.red : "#ffffff"
                font.pixelSize: window.s(12)
            }
            MouseArea {
                id: heartMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; z: 6
                onClicked: window.toggleWatchlist({ imdbId: model.imdbId, title: model.title, poster: model.poster, type: model.type })
            }
        }
        Rectangle {
            anchors.top: parent.top; anchors.right: parent.right; anchors.margins: window.s(7)
            visible: posterCard.removable
            width: window.s(22); height: window.s(22); radius: window.s(11)
            color: removeMouse.containsMouse ? window.red : Qt.rgba(0.08, 0.08, 0.09, 0.55)
            Behavior on color { ColorAnimation { duration: 150 } }
            Text { anchors.centerIn: parent; text: "✕"; color: "#ffffff"; font.pixelSize: window.s(10); font.weight: Font.Bold }
            MouseArea {
                id: removeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; z: 6
                onClicked: posterCard.removeRequested()
            }
            ToolTip.visible: removeMouse.containsMouse
            ToolTip.text: "Remove from history"
            ToolTip.delay: 400
        }
        MouseArea {
            id: posterMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (model.type === "movie") loadMovieDetails(model.imdbId, model.title, model.poster)
                else loadSeriesDetails(model.imdbId, model.title, model.poster)
            }
        }
    }

    Component {
        id: dashboardHeaderComp
        Item {
            width: GridView.view.width
            property bool hasSearch: searchHistoryModel.count > 0
            property bool hasWatch: watchHistoryModel.count > 0
            property bool hasWatchlist: watchlistModel.count > 0
            readonly property real searchSectionH: hasSearch ? (window.s(16) + window.s(12) + window.s(32) + window.s(28)) : 0
            readonly property real watchSectionH: hasWatch ? (window.s(16) + window.s(12) + window.s(200) + window.s(28)) : 0
            readonly property real watchlistSectionH: hasWatchlist ? (window.s(16) + window.s(12) + window.s(200) + window.s(28)) : 0
            readonly property real popularLabelH: window.s(16) + window.s(16)
            height: searchSectionH + watchSectionH + watchlistSectionH + popularLabelH
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: window.s(2)
                spacing: 0
                Item {
                    width: parent.width
                    height: parent.parent.searchSectionH
                    visible: parent.parent.hasSearch
                    Column {
                        width: parent.width
                        spacing: window.s(12)
                        RowLayout {
                            width: parent.width
                            Text {
                                text: "Recent Searches"
                                color: window.text
                                font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(19); font.letterSpacing: -0.3
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "Clear"
                                color: clearSearchHistMouse.containsMouse ? window.red : window.accent
                                font.family: window.fontUI; font.weight: Font.Medium; font.pixelSize: window.s(13)
                                MouseArea { id: clearSearchHistMouse; anchors.fill: parent; anchors.margins: -window.s(6); hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.clearSearchHistory() }
                            }
                        }
                        ListView {
                            width: parent.width; height: window.s(32)
                            orientation: ListView.Horizontal; spacing: window.s(8)
                            model: searchHistoryModel; clip: true; interactive: false
                            add: Transition {
                                ParallelAnimation {
                                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 400 }
                                    NumberAnimation { property: "x"; from: -window.s(20); duration: 400; easing.type: Easing.OutQuart }
                                }
                            }
                            remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 200 } }
                            displaced: Transition { NumberAnimation { property: "x"; duration: 300; easing.type: Easing.OutQuart } }
                            delegate: Rectangle {
                                width: queryText.width + window.s(38); height: window.s(34)
                                radius: window.rLG(); color: histMouse.containsMouse ? window.surface1 : window.surface0
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Text {
                                    id: queryText; text: model.query; color: window.text
                                    font.family: window.fontUI; font.weight: Font.Medium; font.pixelSize: window.s(13)
                                    anchors.left: parent.left; anchors.leftMargin: window.s(15)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                MouseArea {
                                    id: histMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { searchInput.text = model.query; doSearch(model.query) }
                                }
                                Rectangle {
                                    width: window.s(20); height: window.s(20); radius: window.s(10)
                                    color: closeMouse.containsMouse ? window.surface2 : "transparent"
                                    anchors.right: parent.right; anchors.rightMargin: window.s(6)
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text { text: "✕"; anchors.centerIn: parent; color: window.subtext0; font.pixelSize: window.s(9); font.weight: Font.Bold }
                                    MouseArea {
                                        id: closeMouse; anchors.fill: parent; hoverEnabled: true
                                        onClicked: { searchHistoryModel.remove(index); window.saveHistory() }
                                    }
                                }
                            }
                        }
                    }
                }
                Item {
                    width: parent.width
                    height: parent.parent.watchSectionH
                    visible: parent.parent.hasWatch
                    Column {
                        width: parent.width
                        spacing: window.s(12)
                        RowLayout {
                            width: parent.width
                            Text {
                                text: "Continue Watching"
                                color: window.text
                                font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(19); font.letterSpacing: -0.3
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "Clear"
                                color: clearWatchHistMouse.containsMouse ? window.red : window.accent
                                font.family: window.fontUI; font.weight: Font.Medium; font.pixelSize: window.s(13)
                                MouseArea { id: clearWatchHistMouse; anchors.fill: parent; anchors.margins: -window.s(6); hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.clearWatchHistory() }
                            }
                        }
                        ListView {
                            width: parent.width; height: window.s(200)
                            orientation: ListView.Horizontal; spacing: window.s(15)
                            model: watchHistoryModel; clip: true
                            remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 180 } }
                            displaced: Transition { NumberAnimation { property: "x"; duration: 250; easing.type: Easing.OutQuart } }
                            delegate: PosterDelegate {
                                removable: true
                                onRemoveRequested: window.removeFromWatchHistory(index)
                            }
                        }
                    }
                }
                Item {
                    width: parent.width
                    height: parent.parent.watchlistSectionH
                    visible: parent.parent.hasWatchlist
                    Column {
                        width: parent.width
                        spacing: window.s(12)
                        Text {
                            text: "My List"
                            color: window.text
                            font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(19); font.letterSpacing: -0.3
                        }
                        ListView {
                            width: parent.width; height: window.s(200)
                            orientation: ListView.Horizontal; spacing: window.s(15)
                            model: watchlistModel; clip: true
                            delegate: PosterDelegate {}
                        }
                    }
                }
                Item {
                    width: parent.width
                    height: parent.parent.popularLabelH
                    Text {
                        anchors.top: parent.top; anchors.topMargin: window.s(4)
                        text: window.mediaType === "movie" ? "Popular Movies" : "Popular TV Shows"
                        color: window.text
                        font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(19); font.letterSpacing: -0.3
                    }
                }
            }
        }
    }

    // --- UI LAYOUT ---
    Rectangle {
        id: mainBg
        width: parent.width; height: parent.height
        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
        radius: window.rXL()
        color: Qt.rgba(window.base.r, window.base.g, window.base.b, 0.96)
        border.color: window.hairline
        border.width: 1
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: window.shadowColor
            shadowBlur: 0.8; shadowVerticalOffset: 8; shadowOpacity: 0.35
        }
        clip: true
        transform: Translate { y: (1 - window.introPhase) * window.s(50) }
        opacity: window.introPhase
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            visible: window.currentView === "search"
            Rectangle {
                Layout.alignment: Qt.AlignTop; Layout.fillWidth: true
                Layout.preferredHeight: window.s(120) + (window.filterPanelOpen ? window.s(104) : 0)
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 220; easing.type: Easing.OutQuart } }
                color: "transparent"
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: window.s(15); spacing: window.s(10)
                    RowLayout {
                        Layout.fillWidth: true; spacing: window.s(15)
                        Rectangle {
                            // iOS-style segmented control: one neutral track, one
                            // floating white "thumb" with soft shadow — the
                            // selection is communicated by elevation + contrast,
                            // not by color-coding each option.
                            Layout.preferredWidth: window.s(200); Layout.preferredHeight: window.s(36)
                            radius: window.rLG(); color: window.surface0
                            Rectangle {
                                id: tabHighlight
                                width: parent.width / 2 - window.s(4); height: parent.height - window.s(6)
                                y: window.s(3); radius: window.rMD(); color: window.text; z: 0
                                property real targetX: window.mediaType === "movie" ? window.s(3) : (parent.width / 2 + window.s(1))
                                property real actualX: targetX
                                Behavior on actualX { NumberAnimation { duration: 340; easing.type: Easing.OutExpo } }
                                x: actualX
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    shadowEnabled: true; shadowColor: window.shadowColor
                                    shadowBlur: 0.6; shadowVerticalOffset: 2; shadowOpacity: 0.28
                                }
                            }
                            RowLayout {
                                anchors.fill: parent; spacing: 0
                                MouseArea {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    onClicked: { window.mediaType = "movie"; if (searchInput.text !== "") doSearch(searchInput.text) }
                                    Text { anchors.centerIn: parent; text: "Movies"; font.family: window.fontUI; font.weight: window.mediaType === "movie" ? Font.DemiBold : Font.Medium; font.pixelSize: window.s(13); color: window.mediaType === "movie" ? window.base : window.subtext0
                                        Behavior on color { ColorAnimation { duration: 200 } } }
                                }
                                MouseArea {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    onClicked: { window.mediaType = "tv"; if (searchInput.text !== "") doSearch(searchInput.text) }
                                    Text { anchors.centerIn: parent; text: "TV Shows"; font.family: window.fontUI; font.weight: window.mediaType === "tv" ? Font.DemiBold : Font.Medium; font.pixelSize: window.s(13); color: window.mediaType === "tv" ? window.base : window.subtext0
                                        Behavior on color { ColorAnimation { duration: 200 } } }
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            Layout.preferredWidth: window.s(88); Layout.preferredHeight: window.s(36); radius: window.rLG()
                            color: window.filterPanelOpen ? window.text : (filtersBtnMouse.containsMouse ? window.surface1 : window.surface0)
                            Behavior on color { ColorAnimation { duration: 180 } }
                            RowLayout {
                                anchors.centerIn: parent; spacing: window.s(6)
                                Text { text: "⚙"; font.pixelSize: window.s(12); color: window.filterPanelOpen ? window.base : window.text }
                                Text { text: "Filters"; font.family: window.fontUI; font.weight: Font.Medium; font.pixelSize: window.s(12); color: window.filterPanelOpen ? window.base : window.text }
                            }
                            Rectangle {
                                visible: window.filtersActive
                                width: window.s(7); height: window.s(7); radius: window.s(3.5)
                                color: window.filterPanelOpen ? window.base : window.accent
                                anchors.top: parent.top; anchors.right: parent.right; anchors.margins: window.s(3)
                            }
                            MouseArea { id: filtersBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.filterPanelOpen = !window.filterPanelOpen }
                        }
                        CustomComboBox {
                            id: filterSelector
                            Layout.preferredWidth: window.s(180)
                            model: ["Default", "Year (Newest)", "Year (Oldest)", "Title (A-Z)", "Title (Z-A)", "Rating (Best)", "Rating (Worst)"]
                            onActivated: {
                                window.filterSort = currentText
                                applyFiltersAndPopulate()
                                applyFiltersToPopular()
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: window.filterPanelOpen ? window.s(100) : 0
                        clip: true
                        radius: window.rMD()
                        color: window.surface0
                        Behavior on Layout.preferredHeight { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: window.s(14); spacing: window.s(10)
                            opacity: window.filterPanelOpen ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                            RowLayout {
                                Layout.fillWidth: true; spacing: window.s(10)
                                Text { text: "GENRE"; font.family: window.fontUI; font.pixelSize: window.s(10); font.weight: Font.DemiBold; font.letterSpacing: 0.8; color: window.subtext0; Layout.preferredWidth: window.s(42) }
                                Flow {
                                    Layout.fillWidth: true; spacing: window.s(7)
                                    Repeater {
                                        model: window.filterPanelOpen ? window.availableGenres() : []
                                        Rectangle {
                                            property bool active: window.activeGenreFilters.indexOf(modelData) !== -1
                                            width: genreChipText.width + window.s(18); height: window.s(26); radius: window.rLG()
                                            color: active ? window.accent : window.surface1
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            scale: genreChipMouse.pressed ? 0.94 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                                            Text { id: genreChipText; anchors.centerIn: parent; text: modelData; font.family: window.fontUI; font.weight: Font.Medium; font.pixelSize: window.s(11); color: active ? window.base : window.subtext0 }
                                            MouseArea { id: genreChipMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.toggleGenreFilter(modelData) }
                                        }
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true; spacing: window.s(14)
                                Text { text: "YEAR"; font.family: window.fontUI; font.pixelSize: window.s(10); font.weight: Font.DemiBold; font.letterSpacing: 0.8; color: window.subtext0 }
                                Text { text: window.minYearFilter + " – " + window.maxYearFilter; font.family: window.fontUI; font.pixelSize: window.s(12); font.weight: Font.Medium; color: window.text; Layout.preferredWidth: window.s(84) }
                                RangeSlider {
                                    id: yearRange
                                    Layout.fillWidth: true; Layout.maximumWidth: window.s(220)
                                    from: 1950; to: 2026; stepSize: 1
                                    first.value: window.minYearFilter; second.value: window.maxYearFilter
                                    first.onMoved: { window.minYearFilter = Math.round(first.value); applyFiltersAndPopulate(); applyFiltersToPopular() }
                                    second.onMoved: { window.maxYearFilter = Math.round(second.value); applyFiltersAndPopulate(); applyFiltersToPopular() }
                                }
                                Item { Layout.fillWidth: true }
                                Text { text: "RATING"; font.family: window.fontUI; font.pixelSize: window.s(10); font.weight: Font.DemiBold; font.letterSpacing: 0.8; color: window.subtext0 }
                                Slider {
                                    id: ratingSlider
                                    Layout.preferredWidth: window.s(110)
                                    from: 0; to: 9; stepSize: 0.5
                                    value: window.minRatingFilter
                                    onMoved: { window.minRatingFilter = value; applyFiltersAndPopulate(); applyFiltersToPopular() }
                                }
                                Text { text: window.minRatingFilter.toFixed(1) + "+"; font.family: window.fontUI; font.pixelSize: window.s(12); font.weight: Font.Medium; color: window.text; Layout.preferredWidth: window.s(34) }
                                Rectangle {
                                    visible: window.filtersActive
                                    Layout.preferredWidth: window.s(74); Layout.preferredHeight: window.s(28); radius: window.rLG()
                                    color: resetFiltersMouse.containsMouse ? window.red : window.surface1
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text { anchors.centerIn: parent; text: "Reset"; font.family: window.fontUI; font.pixelSize: window.s(11); font.weight: Font.DemiBold; color: resetFiltersMouse.containsMouse ? window.base : window.subtext0 }
                                    MouseArea { id: resetFiltersMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.resetFilters() }
                                }
                            }
                        }
                    }
                    TextField {
                        id: searchInput
                        Layout.fillWidth: true; Layout.preferredHeight: window.s(44)
                        background: Rectangle {
                            color: searchInput.activeFocus ? window.surface1 : window.surface0
                            radius: height / 2
                            border.color: searchInput.activeFocus ? window.accent : "transparent"
                            border.width: searchInput.activeFocus ? 2 : 0
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on border.color { ColorAnimation { duration: 200 } }
                            Text {
                                text: "⌕"
                                anchors.left: parent.left; anchors.leftMargin: window.s(16)
                                anchors.verticalCenter: parent.verticalCenter
                                font.pixelSize: window.s(17)
                                font.weight: Font.DemiBold
                                color: window.subtext0
                            }
                        }
                        color: window.text; font.family: window.fontUI; font.pixelSize: window.s(15); leftPadding: window.s(38)
                        placeholderText: "Search"
                        placeholderTextColor: window.subtext0; verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: {
                            if (text.trim() === "") { searchResults.clear(); window.isSearchingNetwork = false; searchDebounceTimer.stop() }
                            else searchDebounceTimer.restart()
                        }
                        Keys.onRightPressed: {
                            window.isKeyboardNav = true; keyboardNavTimer.restart()
                            let g = getActiveGrid()
                            if (g && g.count > 0 && g.currentIndex < g.count - 1) g.currentIndex++
                            event.accepted = true
                        }
                        Keys.onLeftPressed: {
                            window.isKeyboardNav = true; keyboardNavTimer.restart()
                            let g = getActiveGrid()
                            if (g && g.count > 0 && g.currentIndex > 0) g.currentIndex--
                            event.accepted = true
                        }
                        Keys.onDownPressed: {
                            window.isKeyboardNav = true; keyboardNavTimer.restart()
                            let g = getActiveGrid()
                            if (g && g.count > 0) {
                                let columns = Math.max(1, Math.floor(g.width / g.cellWidth))
                                if (g.currentIndex + columns < g.count) g.currentIndex += columns
                            }
                            event.accepted = true
                        }
                        Keys.onUpPressed: {
                            window.isKeyboardNav = true; keyboardNavTimer.restart()
                            let g = getActiveGrid()
                            if (g && g.count > 0) {
                                let columns = Math.max(1, Math.floor(g.width / g.cellWidth))
                                if (g.currentIndex - columns >= 0) g.currentIndex -= columns
                            }
                            event.accepted = true
                        }
                        Keys.onTabPressed: { window.mediaType = window.mediaType === "movie" ? "tv" : "movie"; if (text.trim() !== "") doSearch(text); event.accepted = true }
                        Keys.onBacktabPressed: { window.mediaType = window.mediaType === "movie" ? "tv" : "movie"; if (text.trim() !== "") doSearch(text); event.accepted = true }
                        Keys.onReturnPressed: {
                            if (text.trim() !== "" && searchResults.count === 0 && !window.isSearchingNetwork) {
                                doSearch(text)
                            } else if (window.isKeyboardNav) {
                                let g = getActiveGrid()
                                if (g && g.count > 0 && g.currentIndex >= 0 && g.currentIndex < g.count) {
                                    let item = g.model.get(g.currentIndex)
                                    if (item) {
                                        if (item.type === "movie") loadMovieDetails(item.imdbId, item.title, item.poster)
                                        else loadSeriesDetails(item.imdbId, item.title, item.poster)
                                    }
                                }
                            }
                            event.accepted = true
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.5) }
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(window.base.r, window.base.g, window.base.b, 0.8)
                    visible: window.isSearchingNetwork || (!window.isSearchMode && window.isLoadingPopular)
                    z: 10
                    ColumnLayout {
                        anchors.centerIn: parent; spacing: window.s(15)
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            width: window.s(34); height: window.s(34)
                            property real spinAngle: 0
                            NumberAnimation on spinAngle {
                                from: 0; to: 360; duration: 900
                                loops: Animation.Infinite; running: true
                                easing.type: Easing.Linear
                            }
                            Canvas {
                                anchors.fill: parent
                                property real angle: parent.spinAngle
                                onAngleChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    var cx = width / 2, cy = height / 2, r = width / 2 - 3
                                    var startRad = (parent.spinAngle - 90) * Math.PI / 180
                                    var endRad = startRad + 1.7 * Math.PI
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, r, startRad, endRad)
                                    ctx.strokeStyle = window.mauve
                                    ctx.lineWidth = 3
                                    ctx.lineCap = "round"
                                    ctx.stroke()
                                }
                            }
                        }
                        Text { Layout.alignment: Qt.AlignHCenter; text: "Loading..."; color: window.text; font.family: window.fontUI; font.pixelSize: window.s(14) }
                    }
                }
                Item {
                    anchors.fill: parent; anchors.margins: window.s(15); visible: !window.isSearchingNetwork
                    Component {
                        id: gridHighlightComp
                        Item {
                            z: 0
                            Rectangle {
                                color: window.surface0; border.color: window.surface1; border.width: 1; radius: window.s(10)
                                property real actX: parent.GridView.view.currentItem ? parent.GridView.view.currentItem.x + window.s(5) : 0
                                property real actY: parent.GridView.view.currentItem ? parent.GridView.view.currentItem.y + window.s(5) : 0
                                x: actX; y: actY; width: parent.GridView.view.cellWidth - window.s(10); height: parent.GridView.view.cellHeight - window.s(10)
                                Behavior on actX { enabled: window.isKeyboardNav; NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
                                Behavior on actY { enabled: window.isKeyboardNav; NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
                                opacity: parent.GridView.view.count > 0 && parent.GridView.view.currentIndex >= 0 ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 300 } }
                            }
                        }
                    }
                    Component {
                        id: mediaGridDelegate
                        Item {
                            id: delegateRoot
                            width: GridView.view.cellWidth; height: GridView.view.cellHeight; z: 1
                            readonly property bool isActive: index === delegateRoot.GridView.view.currentIndex
                            readonly property color accent: model.type === "tv" ? window.blue : window.mauve
                            readonly property bool posterReady: gridImage.status === Image.Ready

                            Rectangle {
                                id: cardRoot
                                anchors.fill: parent; anchors.margins: window.s(6)
                                radius: window.rMD(); color: window.crust; clip: true
                                readonly property bool lifted: cardMouse.containsMouse || (delegateRoot.isActive && window.isKeyboardNav)
                                scale: lifted ? 1.035 : 1.0
                                Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutExpo } }
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    shadowEnabled: true; shadowColor: window.shadowColor
                                    shadowBlur: cardRoot.lifted ? 0.75 : 0.3
                                    shadowVerticalOffset: cardRoot.lifted ? 8 : 2
                                    shadowOpacity: cardRoot.lifted ? 0.42 : 0.18
                                    Behavior on shadowBlur { NumberAnimation { duration: 220 } }
                                    Behavior on shadowVerticalOffset { NumberAnimation { duration: 220 } }
                                    Behavior on shadowOpacity { NumberAnimation { duration: 220 } }
                                }

                                Image {
                                    id: gridImage
                                    anchors.fill: parent
                                    source: model.poster !== "" ? model.poster : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true; smooth: true; cache: true
                                    visible: status === Image.Ready
                                }
                                Rectangle {
                                    anchors.fill: parent; color: window.surface0
                                    visible: model.poster === "" || gridImage.status === Image.Error || gridImage.status === Image.Loading
                                    radius: window.rMD()
                                    property bool isLoading: model.poster !== "" && gridImage.status === Image.Loading
                                    Rectangle {
                                        anchors.fill: parent; radius: window.rMD(); color: "transparent"
                                        visible: parent.isLoading
                                        Rectangle {
                                            width: parent.width * 0.4; height: parent.height
                                            color: Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.4)
                                            property real shimX: -parent.parent.width
                                            x: shimX
                                            NumberAnimation on shimX {
                                                from: -parent.parent.width
                                                to: parent.parent.width * 1.5
                                                duration: 1200; loops: Animation.Infinite
                                                running: parent.parent.parent.isLoading
                                                easing.type: Easing.InOutSine
                                            }
                                        }
                                    }
                                    Text { anchors.centerIn: parent; width: parent.width - window.s(10); text: model.title || "Unknown"; color: window.subtext0; font.family: window.fontUI; font.pixelSize: window.s(12); wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; visible: !parent.isLoading }
                                }

                                // bottom gradient scrim + overlaid title (image-forward card, no text strip below)
                                Rectangle {
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                    height: parent.height * 0.5
                                    visible: delegateRoot.posterReady
                                    gradient: Gradient {
                                        GradientStop { position: 0.0; color: "transparent" }
                                        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
                                    }
                                }
                                ColumnLayout {
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                                    anchors.margins: window.s(11); spacing: window.s(2)
                                    visible: delegateRoot.posterReady
                                    Text {
                                        Layout.fillWidth: true; text: model.title || "Unknown"
                                        font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(13)
                                        color: "#ffffff"; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; lineHeight: 1.15
                                    }
                                    Text {
                                        text: model.year !== "N/A" ? model.year : ""
                                        color: Qt.rgba(1, 1, 1, 0.7); font.family: window.fontUI; font.weight: Font.Medium; font.pixelSize: window.s(11)
                                        visible: text !== ""
                                    }
                                }

                                // rating badge — the only top badge kept; media type
                                // is already obvious from the row/tab context.
                                Rectangle {
                                    anchors.top: parent.top; anchors.right: parent.right; anchors.margins: window.s(9)
                                    visible: delegateRoot.posterReady && (model.rating || 0) > 0
                                    height: window.s(22); width: ratingText.implicitWidth + window.s(16); radius: height / 2
                                    color: Qt.rgba(0.08, 0.08, 0.09, 0.55)
                                    Text {
                                        id: ratingText
                                        anchors.centerIn: parent
                                        text: "★ " + (Math.round((model.rating || 0) * 10) / 10)
                                        color: "#f5c518"; font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(11)
                                    }
                                }
                                // watchlist heart — always reachable on hover/touch, stays
                                // lit once the title has been added so state is obvious at a glance
                                Rectangle {
                                    anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: window.s(9)
                                    visible: delegateRoot.posterReady && (cardMouse.containsMouse || window.isInWatchlist(model.imdbId))
                                    width: window.s(26); height: window.s(26); radius: window.s(13)
                                    color: Qt.rgba(0.08, 0.08, 0.09, 0.55)
                                    Text {
                                        anchors.centerIn: parent
                                        text: window.isInWatchlist(model.imdbId) ? "♥" : "♡"
                                        color: window.isInWatchlist(model.imdbId) ? window.red : "#ffffff"
                                        font.pixelSize: window.s(14)
                                    }
                                    MouseArea {
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; z: 6
                                        onClicked: window.toggleWatchlist({ imdbId: model.imdbId, title: model.title, poster: model.poster, type: model.type })
                                    }
                                }
                            }
                            MouseArea {
                                id: cardMouse
                                anchors.fill: cardRoot
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: { window.isKeyboardNav = false; delegateRoot.GridView.view.currentIndex = index }
                                onClicked: {
                                    if (model.type === "movie") loadMovieDetails(model.imdbId, model.title, model.poster)
                                    else loadSeriesDetails(model.imdbId, model.title, model.poster)
                                }
                            }
                        }
                    }
                    GridView {
                        id: searchGrid
                        anchors.fill: parent; visible: window.isSearchMode
                        model: searchResults; cellWidth: Math.floor(width / 5); cellHeight: cellWidth * 1.5 + window.s(60)
                        boundsBehavior: Flickable.StopAtBounds; highlightFollowsCurrentItem: false; clip: true
                        Behavior on contentY { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
                        add: Transition { ParallelAnimation { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 400; easing.type: Easing.OutQuart } NumberAnimation { property: "y"; from: y + window.s(30); duration: 500; easing.type: Easing.OutQuart } NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: 500; easing.type: Easing.OutBack } } }
                        highlight: gridHighlightComp; delegate: mediaGridDelegate
                    }
                    ColumnLayout {
                        anchors.centerIn: parent; spacing: window.s(8)
                        visible: window.isSearchMode && !window.isSearchingNetwork && searchResults.count === 0 && searchInput.text.trim() !== ""
                        Text { Layout.alignment: Qt.AlignHCenter; text: "⌕"; font.pixelSize: window.s(40); font.weight: Font.Light; color: window.subtext0; opacity: 0.5 }
                        Text { Layout.alignment: Qt.AlignHCenter; text: "No matches for \u201c" + searchInput.text.trim() + "\u201d"; color: window.text; font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(16) }
                        Text { Layout.alignment: Qt.AlignHCenter; text: "Try a different title, or switch between Movies and TV Shows above."; color: window.subtext0; font.family: window.fontUI; font.pixelSize: window.s(12) }
                    }
                    GridView {
                        id: movieGrid
                        anchors.fill: parent; visible: !window.isSearchMode && window.mediaType === "movie"
                        model: cachedTrendingMovies; cellWidth: Math.floor(width / 10); cellHeight: cellWidth * 1.5 + window.s(60)
                        header: dashboardHeaderComp; boundsBehavior: Flickable.StopAtBounds; highlightFollowsCurrentItem: false; clip: true
                        Behavior on contentY { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
                        highlight: gridHighlightComp; delegate: mediaGridDelegate
                    }
                    GridView {
                        id: tvGrid
                        anchors.fill: parent; visible: !window.isSearchMode && window.mediaType === "tv"
                        model: cachedTrendingTv; cellWidth: Math.floor(width / 10); cellHeight: cellWidth * 1.5 + window.s(60)
                        header: dashboardHeaderComp; boundsBehavior: Flickable.StopAtBounds; highlightFollowsCurrentItem: false; clip: true
                        Behavior on contentY { NumberAnimation { duration: 300; easing.type: Easing.OutQuart } }
                        highlight: gridHighlightComp; delegate: mediaGridDelegate
                    }
                }
            }
        }
        // ==========================================
        // SERIES VIEW
        // ==========================================
        RowLayout {
            anchors.fill: parent; anchors.margins: window.s(20); spacing: window.s(25)
            visible: window.currentView === "series"
            ColumnLayout {
                Layout.preferredWidth: window.s(220); Layout.minimumWidth: window.s(220); Layout.maximumWidth: window.s(220)
                Layout.fillHeight: true; spacing: window.s(12)
                Rectangle {
                    // True one-sheet ratio (2:3) at this column's width, so
                    // PreserveAspectCrop has nothing left to crop — the old
                    // fixed s(300) height was shorter than a real poster's
                    // proportions and chopped the top/bottom off every time.
                    Layout.fillWidth: true; Layout.preferredHeight: width * 1.5; radius: window.rLG(); color: window.crust; clip: true
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: window.shadowColor; shadowBlur: 0.6; shadowVerticalOffset: 6; shadowOpacity: 0.3 }
                    Image {
                        id: sideposterImg
                        anchors.fill: parent
                        source: window.selectedPoster !== "" ? window.selectedPoster : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true; smooth: true; cache: true
                        sourceSize.width: window.s(440); sourceSize.height: window.s(660)
                        visible: status === Image.Ready
                        opacity: 0
                        onStatusChanged: if (status === Image.Ready) fadeInSidePoster.start()
                        NumberAnimation { id: fadeInSidePoster; target: sideposterImg; property: "opacity"; to: 1; duration: 220; easing.type: Easing.OutQuad }
                    }
                    // Faint bottom vignette so the frame reads as a deliberate
                    // poster card rather than a bare, flatly-cropped image.
                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                        height: parent.height * 0.28; visible: sideposterImg.status === Image.Ready
                        gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Qt.rgba(0,0,0,0.35) } }
                    }
                    Rectangle {
                        anchors.fill: parent; color: window.surface0; radius: window.rLG()
                        visible: window.selectedPoster === "" || sideposterImg.status === Image.Error || sideposterImg.status === Image.Loading
                        Text { anchors.centerIn: parent; width: parent.width - window.s(10); text: window.selectedTitle; color: window.subtext0; font.family: window.fontUI; font.pixelSize: window.s(14); wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter }
                    }
                }
                Text {
                    Layout.fillWidth: true; text: window.selectedTitle
                    font.family: window.fontUI; font.pixelSize: window.s(19); font.weight: Font.DemiBold; font.letterSpacing: -0.3
                    color: window.text; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                    maximumLineCount: 3; elide: Text.ElideRight
                }
                Flow {
                    Layout.fillWidth: true; spacing: window.s(7)
                    visible: window.selectedRatingLabel !== "" || window.selectedGenres.length > 0
                    Rectangle {
                        visible: window.selectedRatingLabel !== ""
                        width: ratingLbl.width + window.s(16); height: window.s(24); radius: height / 2
                        color: Qt.rgba(0.96, 0.77, 0.09, 0.14)
                        Text { id: ratingLbl; anchors.centerIn: parent; text: window.selectedRatingLabel; color: "#f5c518"; font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(11) }
                    }
                    Rectangle {
                        visible: window.selectedRTRating !== ""
                        width: rtLbl.width + window.s(16); height: window.s(24); radius: height / 2
                        color: Qt.rgba(window.red.r, window.red.g, window.red.b, 0.14)
                        Text { id: rtLbl; anchors.centerIn: parent; text: "🍅 " + window.selectedRTRating; color: window.red; font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(11) }
                    }
                    Rectangle {
                        visible: window.selectedMetacriticRating !== ""
                        width: mcLbl.width + window.s(16); height: window.s(24); radius: height / 2
                        color: Qt.rgba(window.green.r, window.green.g, window.green.b, 0.14)
                        Text { id: mcLbl; anchors.centerIn: parent; text: "MC " + window.selectedMetacriticRating; color: window.green; font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(11) }
                    }
                    Repeater {
                        model: window.selectedGenres.slice(0, 4)
                        Rectangle {
                            width: genreLbl.width + window.s(16); height: window.s(24); radius: height / 2
                            color: window.surface0
                            Text { id: genreLbl; anchors.centerIn: parent; text: modelData; color: window.subtext0; font.family: window.fontUI; font.weight: Font.Medium; font.pixelSize: window.s(11) }
                        }
                    }
                }
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(window.s(110), descText.implicitHeight + window.s(8))
                    Layout.maximumHeight: window.s(110)
                    visible: window.selectedDescription !== ""
                    clip: true; contentHeight: descText.implicitHeight
                    Text {
                        id: descText
                        width: parent.width - window.s(8)
                        text: window.selectedDescription
                        font.family: window.fontUI; font.pixelSize: window.s(11)
                        color: window.subtext0; wrapMode: Text.WordWrap; lineHeight: 1.4
                        Behavior on opacity { NumberAnimation { duration: 400 } }
                        opacity: window.selectedDescription !== "" ? 1 : 0
                    }
                }
                // Cast — a quiet strip of names, not a full credits page.
                ColumnLayout {
                    Layout.fillWidth: true; spacing: window.s(4)
                    visible: window.selectedCast.length > 0
                    Text { text: "CAST"; font.family: window.fontUI; font.pixelSize: window.s(11); font.weight: Font.DemiBold; font.letterSpacing: 0.8; color: window.subtext0; opacity: 0.8 }
                    Text {
                        Layout.fillWidth: true
                        text: window.selectedCast.join(" · ")
                        font.family: window.fontUI; font.pixelSize: window.s(11); color: window.text
                        wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
                    }
                }
                // Trailer — opens on YouTube. Never launches on its own.
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: window.s(42); radius: window.rMD()
                    visible: window.selectedTrailerYtId !== ""
                    color: trailerMouse.containsMouse ? window.surface2 : window.surface1
                    Behavior on color { ColorAnimation { duration: 180 } }
                    RowLayout {
                        anchors.centerIn: parent; spacing: window.s(7)
                        Text { text: "▶"; color: window.red; font.pixelSize: window.s(12) }
                        Text { text: "Watch Trailer"; font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(13); color: window.text }
                    }
                    MouseArea { id: trailerMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.openTrailer() }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: window.s(42); radius: window.rMD()
                    property bool inList: window.isInWatchlist(window.selectedImdbId)
                    color: inList ? Qt.rgba(window.red.r, window.red.g, window.red.b, 0.14) : (watchlistBtnMouse.containsMouse ? window.surface2 : window.surface1)
                    Behavior on color { ColorAnimation { duration: 180 } }
                    RowLayout {
                        anchors.centerIn: parent; spacing: window.s(7)
                        Text { text: parent.parent.inList ? "♥" : "♡"; color: parent.parent.inList ? window.red : window.text; font.pixelSize: window.s(13) }
                        Text { text: parent.parent.inList ? "In My List" : "Add to My List"; font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(13); color: window.text }
                    }
                    MouseArea {
                        id: watchlistBtnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: window.toggleWatchlist({ imdbId: window.selectedImdbId, title: window.selectedTitle, poster: window.selectedPoster, type: window.isMovieDetail ? "movie" : "tv" })
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: window.s(42); radius: window.rMD()
                    property bool isHovered: backMouse.containsMouse
                    color: isHovered ? window.surface2 : window.surface1
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Text { anchors.centerIn: parent; text: "‹  Back"; font.family: window.fontUI; font.pixelSize: window.s(13); font.weight: Font.Medium; color: window.subtext0 }
                    MouseArea { id: backMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { window.currentView = "search"; searchInput.forceActiveFocus(); saveUiState() } }
                }
                Item { Layout.fillHeight: true }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: window.s(12)
                // Movie-only: previously this whole column was just the CTA
                // button with nothing else, leaving most of the panel blank.
                // A backdrop hero card gives it real content (facts + art),
                // and the "More Like This" grid below fills the rest of the
                // space with something actually useful to browse.
                Rectangle {
                    // Fills whatever room is left in the column instead of a
                    // fixed 150px slab — since "More Like This" no longer
                    // eats the rest of this panel, the hero gets to be the
                    // actual centerpiece of the movie detail view.
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: window.rLG()
                    visible: window.isMovieDetail
                    color: window.crust; clip: true
                    Image {
                        id: heroBackdropImg
                        anchors.fill: parent
                        source: window.selectedBackdrop || ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true; smooth: true; cache: true
                        visible: status === Image.Ready
                    }
                    // No backdrop art? Rather than a bare flat panel, fill it
                    // with a softly blurred, darkened blow-up of the poster
                    // itself — a subtle wash of the movie's own art instead
                    // of empty surface color.
                    Image {
                        id: heroPosterFillImg
                        anchors.fill: parent
                        anchors.margins: -window.s(20)
                        source: (heroBackdropImg.status !== Image.Ready && window.selectedPoster !== "") ? window.selectedPoster : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true; smooth: true; cache: true
                        visible: status === Image.Ready && heroBackdropImg.status !== Image.Ready
                        layer.enabled: true
                        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 48; saturation: -0.15 }
                    }
                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(0, 0, 0, 0.32)
                        visible: heroPosterFillImg.status === Image.Ready && heroBackdropImg.status !== Image.Ready
                    }
                    Rectangle {
                        anchors.fill: parent
                        visible: window.selectedBackdrop === "" && heroPosterFillImg.status !== Image.Ready
                        color: window.surface0
                    }
                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.55; color: Qt.rgba(0, 0, 0, 0.25) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
                        }
                    }
                    Flow {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                        anchors.margins: window.s(14)
                        spacing: window.s(8)
                        visible: window.selectedYear !== "" || window.selectedRuntime !== "" || window.selectedDirector !== ""
                        Rectangle {
                            visible: window.selectedYear !== ""
                            width: yearLbl.width + window.s(16); height: window.s(24); radius: height / 2
                            color: Qt.rgba(1, 1, 1, 0.14)
                            Text { id: yearLbl; anchors.centerIn: parent; text: window.selectedYear; color: "#ffffff"; font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(11) }
                        }
                        Rectangle {
                            visible: window.selectedRuntime !== ""
                            width: runtimeLbl.width + window.s(16); height: window.s(24); radius: height / 2
                            color: Qt.rgba(1, 1, 1, 0.14)
                            Text { id: runtimeLbl; anchors.centerIn: parent; text: window.selectedRuntime; color: "#ffffff"; font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(11) }
                        }
                        Rectangle {
                            visible: window.selectedDirector !== ""
                            width: directorLbl.width + window.s(16); height: window.s(24); radius: height / 2
                            color: Qt.rgba(1, 1, 1, 0.14)
                            Text { id: directorLbl; anchors.centerIn: parent; text: "Dir. " + window.selectedDirector; color: "#ffffff"; font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(11); elide: Text.ElideRight }
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: window.s(60); radius: window.rLG()
                    visible: window.isMovieDetail
                    scale: moviePlayMouse.pressed ? 0.98 : 1.0
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                    color: moviePlayMouse.containsMouse ? Qt.lighter(window.accent, 1.08) : window.accent
                    Behavior on color { ColorAnimation { duration: 150 } }
                    layer.enabled: true
                    layer.effect: MultiEffect { shadowEnabled: true; shadowColor: window.shadowColor; shadowBlur: 0.6; shadowVerticalOffset: 4; shadowOpacity: 0.25 }
                    Text {
                        anchors.centerIn: parent; text: "▶  Find a Source & Play"
                        font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(17); font.letterSpacing: -0.2
                        color: window.base
                    }
                    MouseArea {
                        id: moviePlayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: startSourceCheck("movie", window.selectedImdbId, window.selectedTitle, window.selectedPoster, 0, 0)
                    }
                }
                Item {
                    Layout.fillWidth: true; Layout.preferredHeight: window.s(44)
                    visible: !window.isMovieDetail
                    ListView {
                        id: seasonList
                        anchors.fill: parent
                        orientation: ListView.Horizontal; model: seasonModel; spacing: window.s(8); clip: true
                        Behavior on contentX { NumberAnimation { duration: 350; easing.type: Easing.OutQuart } }
                        delegate: Rectangle {
                            width: seasonLabelText.width + window.s(28); height: window.s(38); radius: height / 2
                            property bool isActive: window.currentSeason === model.seasonNum
                            color: isActive ? window.text : window.surface0
                            Behavior on color { ColorAnimation { duration: 280; easing.type: Easing.OutExpo } }
                            scale: isActive ? 1.03 : 1.0
                            Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutExpo } }
                            Text {
                                id: seasonLabelText
                                anchors.centerIn: parent
                                text: "S" + model.seasonNum
                                font.family: window.fontUI; font.pixelSize: window.s(13); font.weight: isActive ? Font.DemiBold : Font.Medium
                                color: isActive ? window.base : window.subtext0
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (window.currentSeason !== model.seasonNum) {
                                        window.currentSeason = model.seasonNum
                                        updateEpisodes(model.seasonNum)
                                        saveUiState()
                                    }
                                }
                            }
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(window.surface1.r, window.surface1.g, window.surface1.b, 0.5); visible: !window.isMovieDetail }
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    visible: !window.isMovieDetail
                    ListView {
                        id: epList
                        anchors.fill: parent
                        model: episodeModel; spacing: window.s(6); clip: true
                        opacity: window.seasonSwitching ? 0 : 1
                        Behavior on opacity {
                            NumberAnimation {
                                duration: window.seasonSwitching ? 180 : 250
                                easing.type: window.seasonSwitching ? Easing.InQuad : Easing.OutQuad
                            }
                        }
                        transform: Translate {
                            y: window.seasonSwitching ? window.s(8) : 0
                            Behavior on y {
                                NumberAnimation {
                                    duration: window.seasonSwitching ? 180 : 280
                                    easing.type: window.seasonSwitching ? Easing.InQuad : Easing.OutQuart
                                }
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: window.isLoadingSeries
                            text: "Fetching episodes..."
                            color: window.subtext0; font.family: window.fontUI; font.pixelSize: window.s(13)
                        }
                        highlight: Rectangle {
                            color: window.surface0; radius: window.rSM(); z: 0
                            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutExpo } }
                        }
                        highlightFollowsCurrentItem: true
                        highlightMoveVelocity: -1
                        delegate: Item {
                            width: ListView.view.width; height: window.s(58); z: 1
                            property bool isCurrent: ListView.isCurrentItem
                            Rectangle {
                                anchors.fill: parent; radius: window.rSM()
                                color: epMouse.containsMouse || isCurrent ? window.surface0 : "transparent"
                                Behavior on color { ColorAnimation { duration: 180 } }
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: window.s(10); spacing: window.s(12)
                                    Rectangle {
                                        Layout.preferredWidth: window.s(36); Layout.preferredHeight: window.s(36)
                                        radius: window.rXS()
                                        color: isCurrent || epMouse.containsMouse ? window.accent : window.surface1
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: model.epNum
                                            font.family: window.fontUI; font.pixelSize: window.s(13); font.weight: Font.DemiBold
                                            color: isCurrent || epMouse.containsMouse ? window.base : window.subtext0
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                        }
                                    }
                                    Column {
                                        Layout.fillWidth: true; spacing: window.s(2)
                                        Text {
                                            width: parent.width
                                            text: model.epTitle
                                            font.family: window.fontUI
                                            font.pixelSize: model.hasRealTitle ? window.s(13) : window.s(12)
                                            font.weight: model.hasRealTitle ? Font.Medium : Font.Normal
                                            color: model.hasRealTitle ? window.text : window.subtext0
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                                MouseArea {
                                    id: epMouse; anchors.fill: parent; hoverEnabled: true
                                    onClicked: {
                                        epList.currentIndex = index
                                        startSourceCheck("tv", window.selectedImdbId, window.selectedTitle, window.selectedPoster, window.currentSeason, model.epNum)
                                    }
                                }
                            }
                        }
                    }
                }
                // Similar titles — cheap genre-overlap heuristic against the
                // trending cache, no extra network round trip.
                // TV keeps the slim horizontal strip since the episode list
                // above it already fills the space.
                ColumnLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: window.s(150); spacing: window.s(6)
                    visible: !window.isMovieDetail && window.similarTitles.length > 0
                    Text { text: "MORE LIKE THIS"; font.family: window.fontUI; font.pixelSize: window.s(11); font.weight: Font.DemiBold; font.letterSpacing: 0.8; color: window.subtext0; opacity: 0.8 }
                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        orientation: ListView.Horizontal; spacing: window.s(10); clip: true
                        model: window.similarTitles
                        delegate: Rectangle {
                            width: window.s(90); height: window.s(128); radius: window.rSM(); color: window.crust; clip: true
                            Image {
                                anchors.fill: parent
                                source: modelData.poster || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true; smooth: true
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                width: parent.width - window.s(8)
                                text: modelData.title
                                visible: parent.children[0].status !== Image.Ready
                                color: window.subtext0; font.family: window.fontUI; font.pixelSize: window.s(10)
                                wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                            }
                            Rectangle {
                                anchors.bottom: parent.bottom; width: parent.width; height: window.s(28)
                                gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Qt.rgba(0,0,0,0.75) } }
                                Text {
                                    anchors.bottom: parent.bottom; anchors.margins: window.s(4); width: parent.width - window.s(8); anchors.left: parent.left; anchors.leftMargin: window.s(4)
                                    text: modelData.title; color: window.text; font.family: window.fontUI; font.pixelSize: window.s(9)
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.type === "movie") loadMovieDetails(modelData.imdbId, modelData.title, modelData.poster)
                                    else loadSeriesDetails(modelData.imdbId, modelData.title, modelData.poster)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    // ==========================================
    // SOURCE CHECKER MODAL OVERLAY
    // ==========================================
    Rectangle {
        id: sourceModalOverlay
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.55) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.82) }
        }
        opacity: window.isSourceModalOpen ? 1 : 0
        visible: opacity > 0
        clip: true
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
        z: 100
        MouseArea {
            anchors.fill: parent
            onClicked: window.closeSourceModal()
        }
        Item {
            id: modalWrapper
            // Clamp to the panel's actual size (minus breathing room) so the
            // card can never render outside the visible surface, regardless
            // of how small the host panel is.
            width: Math.min(window.s(560), window.width - window.s(32))
            height: Math.min(window.s(660), window.height - window.s(32))
            anchors.centerIn: parent
            scale: window.isSourceModalOpen ? 1.0 : 0.92
            Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }

            // real soft elevation shadow (Apple-style floating sheet)
            Rectangle {
                id: modalCard
                anchors.fill: parent
                radius: window.rXL()
                color: window.base
                clip: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true; shadowColor: window.shadowColor
                    shadowBlur: 1.0; shadowVerticalOffset: 14; shadowOpacity: 0.5
                }
                MouseArea { anchors.fill: parent }
                ColumnLayout {
                    anchors.fill: parent; spacing: 0
                    // Header
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: window.s(92)
                        color: window.surface0
                        RowLayout {
                            anchors.fill: parent; anchors.margins: window.s(16); spacing: window.s(14)
                            Rectangle {
                                Layout.preferredWidth: window.s(56); Layout.preferredHeight: window.s(56)
                                radius: window.rSM(); color: window.crust; clip: true
                                Image {
                                    anchors.fill: parent
                                    source: window.pendingMedia.poster || ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true; smooth: true
                                    visible: status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: window.pendingMedia.type === "tv" ? "📺" : "🎬"
                                    font.pixelSize: window.s(20)
                                    visible: !(window.pendingMedia.poster && window.pendingMedia.poster !== "")
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: window.s(6)
                                Text {
                                    text: window.pendingMedia.title || "Loading..."
                                    color: window.text; font.family: window.fontUI; font.weight: Font.DemiBold; font.pixelSize: window.s(19); font.letterSpacing: -0.3
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                                Text {
                                    visible: window.pendingMedia.type === "tv"
                                    text: "Season " + (window.pendingMedia.season || 1) + " · Episode " + (window.pendingMedia.ep || 1)
                                    color: window.subtext0; font.family: window.fontUI; font.pixelSize: window.s(11)
                                }
                                Text {
                                    text: window.checkingState === "checking"   ? "Checking sources in the background…"
                                        : window.checkingState === "failed_all" ? "No source auto-verified — pick one below"
                                        :                                        "Tap any source below to play"
                                    color: window.subtext0
                                    font.family: window.fontUI; font.pixelSize: window.s(11)
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                }
                            }
                            Rectangle {
                                Layout.preferredWidth: window.s(32); Layout.preferredHeight: window.s(32); radius: window.s(16)
                                Layout.alignment: Qt.AlignTop
                                color: modalCloseMouse.containsMouse ? window.surface2 : window.surface1
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Text { anchors.centerIn: parent; text: "✕"; color: window.subtext0; font.pixelSize: window.s(13); font.weight: Font.Bold }
                                MouseArea { id: modalCloseMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: window.closeSourceModal() }
                            }
                        }
                    }
                    // Search
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: window.s(56); color: window.surface0
                        Rectangle {
                            anchors.fill: parent; anchors.margins: window.s(10)
                            radius: window.rMD(); color: window.base
                            border.color: sourceSearchField.activeFocus ? window.accent : "transparent"
                            border.width: sourceSearchField.activeFocus ? 2 : 0
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: window.s(14); anchors.rightMargin: window.s(10); spacing: window.s(8)
                                Text { text: "⌕"; font.pixelSize: window.s(15); font.weight: Font.DemiBold; color: window.subtext0 }
                                TextInput {
                                    id: sourceSearchField
                                    Layout.fillWidth: true
                                    text: window.sourceSearchQuery
                                    onTextChanged: window.sourceSearchQuery = text
                                    font.family: window.fontUI; font.pixelSize: window.s(13)
                                    color: window.text
                                    clip: true
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "Search sources..."
                                        color: window.subtext0
                                        font: sourceSearchField.font
                                        visible: sourceSearchField.text.length === 0
                                    }
                                }
                                Rectangle {
                                    visible: sourceSearchField.text.length > 0
                                    Layout.preferredWidth: window.s(20); Layout.preferredHeight: window.s(20); radius: window.s(10)
                                    color: clearSearchMouse.containsMouse ? window.surface2 : "transparent"
                                    Text { anchors.centerIn: parent; text: "×"; color: window.subtext0; font.pixelSize: window.s(13) }
                                    MouseArea { id: clearSearchMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { sourceSearchField.text = "" } }
                                }
                            }
                        }
                    }
                // Body
                ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0

                    // Banner shown when the auto-checker gave up. The full list stays
                    // visible below it so the user can still pick a source themselves.
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.margins: window.s(14)
                        Layout.bottomMargin: 0
                        spacing: window.s(10)
                        visible: window.checkingState === "failed_all"
                        Text {
                            Layout.fillWidth: true
                            text: "Auto-check couldn't confirm a source. Tap any source below to open it yourself, or:"
                            color: window.subtext0; font.family: window.fontUI; font.pixelSize: window.s(12)
                            wrapMode: Text.WordWrap; lineHeight: 1.3
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: window.s(40); radius: window.s(10)
                            color: fmhyMouse.containsMouse ? window.blue : window.surface1
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text { anchors.centerIn: parent; text: "Browse Alternative Sites"; font.family: window.fontUI; font.weight: Font.Bold; font.pixelSize: window.s(12); color: fmhyMouse.containsMouse ? window.crust : window.text }
                            MouseArea {
                                id: fmhyMouse; anchors.fill: parent; hoverEnabled: true
                                onClicked: { Quickshell.execDetached(["xdg-open", "https://fmhy.net/video#streaming-sites"]); window.closeSourceModal() }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: window.surface1; Layout.topMargin: window.s(4) }
                    }

                    ListView {
                        id: sourceListUI
                        Layout.fillWidth: true; Layout.fillHeight: true
                        leftMargin: window.s(14); topMargin: window.s(10); bottomMargin: window.s(14)
                        model: sourceModel; spacing: window.s(9); clip: true
                        delegate: Rectangle {
                            id: sourceRow
                            readonly property bool matchesSearch: window.sourceSearchQuery.trim() === "" || model.name.toLowerCase().indexOf(window.sourceSearchQuery.trim().toLowerCase()) !== -1
                            readonly property bool isPreferredRow: (window.sourcePrefs[window.pendingMedia.imdbId || ""] || "") === model.name
                            readonly property color statusColor: model.status === "success"  ? window.green
                                                               : model.status === "checking" ? window.blue
                                                               : model.status === "failed"   ? window.red
                                                               :                               window.subtext0
                            width: ListView.view.width
                            height: matchesSearch ? window.s(70) : 0
                            opacity: matchesSearch ? 1 : 0
                            visible: matchesSearch
                            clip: true
                            radius: window.rMD()
                            scale: rowMouse.pressed ? 0.988 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutQuart } }
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            color: {
                                if (model.status === "success")  return Qt.rgba(window.green.r, window.green.g, window.green.b, 0.10)
                                if (rowMouse.containsMouse)      return window.surface1
                                if (model.status === "checking") return Qt.rgba(window.blue.r,  window.blue.g,  window.blue.b,  0.10)
                                if (model.status === "failed")   return Qt.rgba(window.red.r,   window.red.g,   window.red.b,   0.06)
                                return window.surface0
                            }
                            Behavior on color { ColorAnimation { duration: 150 } }
                            // A slim accent bar reads status/preference at a
                            // glance without needing a full-perimeter border,
                            // which kept every row visually "shouting".
                            Rectangle {
                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                anchors.margins: window.s(6)
                                width: window.s(3); radius: window.s(2)
                                color: sourceRow.isPreferredRow ? window.accent : sourceRow.statusColor
                                opacity: model.status === "pending" && !sourceRow.isPreferredRow ? 0.25 : 0.85
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                z: 5
                                onClicked: window.selectSourceManually(index)
                            }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: window.s(20); anchors.rightMargin: window.s(14)
                                spacing: window.s(13)
                                Item {
                                    Layout.preferredWidth: window.s(38); Layout.preferredHeight: window.s(38)
                                    // A calm, consistent avatar: accent-tinted
                                    // when it's the preferred source, a soft
                                    // status tint once it's been checked, and
                                    // a neutral surface otherwise — instead of
                                    // a rainbow cycling on row index, which
                                    // read as random rather than meaningful.
                                    Rectangle {
                                        anchors.fill: parent; radius: window.rSM()
                                        color: sourceRow.isPreferredRow ? window.accent
                                             : model.status === "pending" ? window.surface1
                                             : Qt.rgba(sourceRow.statusColor.r, sourceRow.statusColor.g, sourceRow.statusColor.b, 0.20)
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: model.name.charAt(0).toUpperCase()
                                            color: sourceRow.isPreferredRow ? window.base
                                                 : model.status === "pending" ? window.subtext0
                                                 : sourceRow.statusColor
                                            font.family: window.fontUI; font.weight: Font.Bold; font.pixelSize: window.s(15)
                                        }
                                    }
                                    // Small rank badge — sources are checked
                                    // in this order, so surfacing "#1, #2…"
                                    // makes the auto-check sequence legible.
                                    Rectangle {
                                        anchors.top: parent.top; anchors.left: parent.left
                                        anchors.topMargin: -window.s(5); anchors.leftMargin: -window.s(5)
                                        width: window.s(17); height: window.s(17); radius: window.s(8.5)
                                        color: window.base; border.color: window.surface1; border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: (index + 1)
                                            color: window.subtext0; font.family: window.fontUI; font.weight: Font.Bold; font.pixelSize: window.s(9)
                                        }
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: window.s(3)
                                    RowLayout {
                                        spacing: window.s(6)
                                        Text {
                                            text: model.name
                                            font.family: window.fontUI; font.weight: Font.Bold; font.pixelSize: window.s(14)
                                            color: model.status !== "pending" ? sourceRow.statusColor : window.text
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                        }
                                        Rectangle {
                                            visible: sourceRow.isPreferredRow
                                            Layout.preferredHeight: window.s(16)
                                            Layout.preferredWidth: preferredLbl.width + window.s(12)
                                            radius: height / 2
                                            color: Qt.rgba(window.accent.r, window.accent.g, window.accent.b, 0.16)
                                            Text {
                                                id: preferredLbl
                                                anchors.centerIn: parent
                                                text: "★ Preferred"
                                                font.family: window.fontUI; font.weight: Font.Bold; font.pixelSize: window.s(9); color: window.accent
                                            }
                                        }
                                    }
                                    Text {
                                        text: model.status === "pending"   ? "Tap to play"
                                            : model.status === "checking" ? "Checking availability…"
                                            : model.status === "success"  ? "Verified reachable — tap to play"
                                            : model.status === "failed"   ? "Unreachable — tap to try anyway"
                                            :                               ""
                                        font.family: window.fontUI; font.pixelSize: window.s(11); color: window.subtext0
                                        elide: Text.ElideRight; Layout.fillWidth: true
                                    }
                                }
                                // Inline row actions — star to prefer, copy to
                                // grab the raw link. These used to live in a
                                // big footer that only appeared once the
                                // auto-checker picked a "winner"; now they
                                // travel with every row since any row can be
                                // played directly, any time.
                                Rectangle {
                                    Layout.preferredWidth: window.s(30); Layout.preferredHeight: window.s(30); radius: window.rSM()
                                    color: preferMouse.containsMouse ? window.surface2 : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: sourceRow.isPreferredRow ? "★" : "☆"
                                        font.pixelSize: window.s(15)
                                        color: sourceRow.isPreferredRow ? window.accent : window.subtext0
                                    }
                                    MouseArea {
                                        id: preferMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; z: 10
                                        onClicked: {
                                            if (window.pendingMedia.imdbId) saveSourcePref(window.pendingMedia.imdbId, model.name)
                                        }
                                    }
                                    ToolTip.visible: preferMouse.containsMouse
                                    ToolTip.text: sourceRow.isPreferredRow ? "Preferred source" : "Mark as preferred"
                                    ToolTip.delay: 400
                                }
                                Rectangle {
                                    Layout.preferredWidth: window.s(30); Layout.preferredHeight: window.s(30); radius: window.rSM()
                                    color: rowCopyMouse.containsMouse ? window.surface2 : "transparent"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: window.linkCopiedToast && window.currentCheckIndex === index ? "✓" : "⧉"
                                        font.pixelSize: window.s(13)
                                        color: window.linkCopiedToast && window.currentCheckIndex === index ? window.green : window.subtext0
                                    }
                                    MouseArea {
                                        id: rowCopyMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; z: 10
                                        onClicked: window.copyStreamLink(index)
                                    }
                                    ToolTip.visible: rowCopyMouse.containsMouse
                                    ToolTip.text: "Copy link"
                                    ToolTip.delay: 400
                                }
                                // Trailing status pill — a labelled chip reads
                                // faster than a bare glyph and gives the
                                // checking/failed/success states equal visual
                                // weight to the source name itself.
                                Rectangle {
                                    Layout.preferredHeight: window.s(26)
                                    Layout.preferredWidth: statusRow.width + window.s(16)
                                    radius: height / 2
                                    color: model.status === "pending" ? "transparent"
                                         : Qt.rgba(sourceRow.statusColor.r, sourceRow.statusColor.g, sourceRow.statusColor.b, 0.14)
                                    border.color: model.status === "pending" ? window.surface2 : "transparent"
                                    border.width: 1
                                    RowLayout {
                                        id: statusRow
                                        anchors.centerIn: parent
                                        spacing: window.s(5)
                                        Item {
                                            Layout.preferredWidth: window.s(12); Layout.preferredHeight: window.s(12)
                                            visible: model.status === "checking"
                                            property real spinAngle: 0
                                            NumberAnimation on spinAngle {
                                                from: 0; to: 360; duration: 700
                                                loops: Animation.Infinite
                                                running: model.status === "checking"
                                                easing.type: Easing.Linear
                                            }
                                            Canvas {
                                                anchors.fill: parent
                                                property real angle: parent.spinAngle
                                                onAngleChanged: requestPaint()
                                                onPaint: {
                                                    var ctx = getContext("2d")
                                                    ctx.reset()
                                                    var cx = width / 2, cy = height / 2, r = width / 2 - 1.5
                                                    var startRad = (parent.spinAngle - 90) * Math.PI / 180
                                                    var endRad   = startRad + 1.6 * Math.PI
                                                    ctx.beginPath()
                                                    ctx.arc(cx, cy, r, startRad, endRad)
                                                    ctx.strokeStyle = window.blue
                                                    ctx.lineWidth = 2
                                                    ctx.lineCap = "round"
                                                    ctx.stroke()
                                                }
                                            }
                                        }
                                        Text {
                                            visible: model.status === "success"
                                            text: "✓"; color: window.green; font.weight: Font.Bold; font.pixelSize: window.s(12)
                                        }
                                        Text {
                                            visible: model.status === "failed"
                                            text: "↻"; color: window.red; font.weight: Font.Bold; font.pixelSize: window.s(12)
                                        }
                                        Text {
                                            text: model.status === "pending"   ? "Play ›"
                                                : model.status === "checking" ? "Checking"
                                                : model.status === "success"  ? "Play ✓"
                                                :                               "Retry"
                                            font.family: window.fontUI; font.weight: Font.Bold; font.pixelSize: window.s(10)
                                            color: model.status === "pending" ? window.subtext0 : sourceRow.statusColor
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        }
    }
}
