import QtQuick

// Thin wrapper around Image that loads a remote poster URL (metahub serves
// WebP, decoded natively once qt6-imageformats is installed). Exists so the
// six poster slots share one consistent fill/async config.
Image {
    id: poster

    property string url: ""

    source: url || ""
    asynchronous: true
    cache: true
    fillMode: Image.PreserveAspectCrop
    smooth: true
}
