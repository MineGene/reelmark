/// Reelmark's own TMDB access token, so the app works with no setup.
///
/// It's public on purpose: anything shipped inside an app can be read out
/// of it, and this repository is open source. It only allows reading TMDB's
/// public catalogue (the "api_read" scope), never changes anything, and
/// identifies Reelmark, not the person using it. People who'd rather use
/// their own token can add one in Settings; it's kept in their Keychain and
/// used instead of this one.
enum TMDBKey {
    static let builtIn =
        "eyJhbGciOiJIUzI1NiJ9.eyJhdWQiOiI5OTY2ZDg5ZGU1ZTBkZWZkODE5YzYxNThiMTFhOWVmNyIsIm5iZiI6MTcxMzE2MDQxOS45MTgwMDAyLCJzdWIiOiI2NjFjYzBlM2U0ODg2MDAxNjIzYWE2OGIiLCJzY29wZXMiOlsiYXBpX3JlYWQiXSwidmVyc2lvbiI6MX0.xBeUObqqjyhVLndb42ytY7npnTK9UGEN65vHLSpekqE"
}
