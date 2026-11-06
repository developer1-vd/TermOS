/* TermOS installer slideshow, shown while Calamares installs. */
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    Timer {
        interval: 10000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    // One slide: rain background, a title and a line of text.
    component TermSlide: Slide {
        id: termSlide
        property string title
        property string body

        Image {
            anchors.fill: parent
            source: "slide-bg.png"
            fillMode: Image.PreserveAspectCrop
        }
        Column {
            anchors.centerIn: parent
            width: parent.width * 0.8
            spacing: 18
            Text {
                width: parent.width
                text: termSlide.title
                color: "#00FF66"
                font.family: "monospace"
                font.pixelSize: 34
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: termSlide.body
                color: "#C8FFD7"
                font.family: "monospace"
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }

    TermSlide {
        title: "Welcome to TermOS"
        body: "Fedora at its core, with Ubuntu and Nix on top, and a KDE Plasma desktop."
    }
    TermSlide {
        title: "Run anything"
        body: "termos-run starts Windows apps with Wine, macOS apps with Darling, BSD apps in a VM, and Nix and Ubuntu apps too."
    }
    TermSlide {
        title: "Three package sources"
        body: "dnf for the system, Nix for reproducible per-user setups, and Ubuntu packages in a Distrobox container. Flathub is ready to go."
    }
    TermSlide {
        title: "Feeling lucky?"
        body: "Run termos-fetch for the Matrix logo, or fortune | termos-fetch to meet the termite."
    }

    function onActivate() {
        presentation.currentSlide = 0;
    }
    function onLeave() {
    }
}
