// Plasma update script: sets the TermOS wallpaper on every desktop.
// Installed to /usr/share/plasma/shells/org.kde.plasma.desktop/contents/updates/.
// Plasma runs each update script once per user, so users can still change
// their wallpaper afterwards and it won't be reset.
desktops().forEach(function (d) {
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/wallpapers/TermOS/");
    d.writeConfig("PreviewImage", "file:///usr/share/wallpapers/TermOS/");
});
