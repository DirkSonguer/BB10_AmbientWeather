// *************************************************** //
// Main Page
//
// This is the main page of the AmbientWeather application
// It contains the main page components as well as the
// orchestration locig.
// *************************************************** //

// import blackberry components
import bb.cascades 1.0

// import geolocation services
import QtMobilitySubset.location 1.1

// import url loader workaround
import org.labsquare 1.0

// set import directory for components
import "components"

// shared js files
import "global/globals.js" as Globals
import "classes/flickrapi.js" as FlickrAPI
import "classes/locationapi.js" as LocationAPI
import "classes/weatherapi.js" as WeatherAPI
import "classes/locationmanager.js" as LocationManager
import "classes/swipehandler.js" as SwipeHandler
import "classes/settingsmanager.js" as SettingsManager
import "structures/geolocationdata.js" as GeolocationData

NavigationPane {
    id: navigationPane

    Page {
        id: ambientWeatherMainPage

        // property for the current geolocation
        // contains lat and lon
        property variant currentGeolocation

        // property for the weather for current location
        // this is of type LocationData
        property variant currentWeatherdata

        // property for the current application settings
        // this is of type ApplicationSettings
        property variant currentApplicationSettings

        // property for the images for current location
        // this is an array of type FlickrImageData
        property variant currentImagedata

        // the current search radius for images
        // this might change dynamically if no images are found and the radius is widened
        property real currentLocationSearchRadius: Globals.locationSearchRadius

        // flickr api signals
        signal imageDataLoaded(variant imageDataArray)
        signal imageDataError(variant errorData)

        // weather api signals
        signal weatherDataLoaded(variant weatherData)
        signal weatherDataError(variant errorData)

        // change location signal
        // this will be called by other pages if a new location should be used
        signal changeLocation(variant locationData)

        // signal that the settings have been updated
        signal updateApplicationSettings()

        Container {
            layout: DockLayout {
            }

            // background image
            // the component also contains the logic for changing images and their transitions
            BackgroundImage {
                id: backgroundImage
            }

            // wrapper component for the light black background
            Container {
                // style definition
                // this defines the bottom margin
                verticalAlignment: VerticalAlignment.Bottom
                horizontalAlignment: HorizontalAlignment.Right
                bottomPadding: ((DisplayInfo.height / 12) - 20)

                // actual light black background
                Container {
                    id: backgroundDashboard

                    // style definition
                    preferredHeight: (weatherDashboard.currentHeight - ((DisplayInfo.height / 12) - 30))
                    preferredWidth: DisplayInfo.width
                    background: Color.Black
                    opacity: 0.2
                }
            }

            // weather dashboard
            // this contains all components for showing weather data and icons
            WeatherDashboard {
                id: weatherDashboard

                // bottom padding is dynamic according to screen size
                bottomPadding: (DisplayInfo.height / 12)
                rightPadding: 20
            }

            // context menu for image gallery
            contextActions: [
                ActionSet {
                    title: "Ambient Weather"
                    subtitle: "Where are you?"

                    // use current location
                    ActionItem {
                        title: "Use my current location"
                        imageSource: "asset:///images/icon_currentlocation.png"

                        // action called
                        onTriggered: {
                            // console.log("# Getting current location");

                            // stop position query just to make sure it doesn't run anymore
                            positionSource.stop();

                            // reset information labels
                            weatherDashboard.weatherLocation = "Ambient Weather";
                            weatherDashboard.weatherCondition = "Getting your position..";

                            // reset the current location if one was previously set
                            LocationManager.resetActiveLocation();

                            // start getting location
                            positionSource.start();
                        }
                    }
                    // change current location from manual list
                    ActionItem {
                        title: "Choose location manually"
                        imageSource: "asset:///images/icon_managelocation.png"

                        // switch to location list page
                        onTriggered: {
                            var locationManagementPage = locationManagementComponent.createObject();
                            navigationPane.push(locationManagementPage);
                        }
                    }
                }
            ]

            onTouch: {
                // start the swipe handler on touch down and analyze the data on touch up
                if (event.isDown()) {
                    // store start position of gesture
                    SwipeHandler.swipeHandler.startSwipeCapture(event);
                } else if (event.isUp()) {
                    // analyze end position of gesture
                    var swipeResult = SwipeHandler.swipeHandler.analyzeSwipeCapture(event);

                    // check if a swipe has been catched and act accordingly
                    if (swipeResult == SwipeHandler.swipeHandler.SWIPELEFT) {
                        backgroundImage.showNextImage();
                    } else if (swipeResult == SwipeHandler.swipeHandler.SWIPERIGHT) {
                        backgroundImage.showPrevImage();
                    } else if (swipeResult == SwipeHandler.swipeHandler.SWIPEUP) {
                        console.log("# up");
                    } else if (swipeResult == SwipeHandler.swipeHandler.SWIPEDOWN) {
                        console.log("# down");
                    }
                }
            }
        }

        // app is loaded and page is available
        onCreationCompleted: {
            // loading default image
            backgroundImage.showLocalImage("asset:///images/ambient_weather_intro.png");

            // load and update application settings
            updateApplicationSettings();

            //  get  available, stored locations
            var activeLocation = new Array;
            activeLocation = LocationManager.getActiveLocation();

            // check if an active location is set
            if (activeLocation.display_name != null) {
                // console.log("# Using active location " + activeLocation.display_name);

                // reset weather background image and dashboard
                backgroundImage.showLocalImage("asset:///images/ambient_weather_intro.png");
                weatherDashboard.resetDashboard();

                // create geolocation object and fill it with location data
                var locationCoordinates = new GeolocationData.GeolocationData;
                locationCoordinates.latitude = activeLocation.lat;
                locationCoordinates.longitude = activeLocation.lon;

                // set location data and load weather data
                ambientWeatherMainPage.currentGeolocation = locationCoordinates;
                WeatherAPI.getWeatherData(ambientWeatherMainPage.currentGeolocation, ambientWeatherMainPage);
            } else {
                // console.log("# No active location set, starting location fix");
                positionSource.start()
            }
        }

        // load and update application settings
        onUpdateApplicationSettings: {
            // load settings
            ambientWeatherMainPage.currentApplicationSettings = new Array();
            ambientWeatherMainPage.currentApplicationSettings = SettingsManager.getSettings();

            // if this is the first application start the app actually does not have settings yet
            // thus reset settings for first use
            if (ambientWeatherMainPage.currentApplicationSettings == undefined) {
                SettingsManager.resetSettings();
                ambientWeatherMainPage.currentApplicationSettings = SettingsManager.getSettings();
            }

            // load weather data into component again in case temperature scale has changed
            if (ambientWeatherMainPage.currentWeatherdata !== undefined) {
                weatherDashboard.setWeatherData(ambientWeatherMainPage.currentWeatherdata, ambientWeatherMainPage.currentImagedata);
            }
        }

        // change location
        onChangeLocation: {
            // console.log("# Location changed !");
            // reset weather background image and dashboard
            backgroundImage.showLocalImage("asset:///images/ambient_weather_intro.png");
            weatherDashboard.resetDashboard();

            // create geolocation object and fill it with location data
            var locationCoordinates = new GeolocationData.GeolocationData;
            locationCoordinates.latitude = locationData.lat;
            locationCoordinates.longitude = locationData.lon;

            // set location data and load weather data
            ambientWeatherMainPage.currentGeolocation = locationCoordinates;
            WeatherAPI.getWeatherData(ambientWeatherMainPage.currentGeolocation, ambientWeatherMainPage);
        }

        // image data loaded from flickr
        onImageDataLoaded: {
            // check if images exist for location
            if (imageDataArray.length > 0) {
                console.log("# Found " + imageDataArray.length + " images for location " + ambientWeatherMainPage.currentGeolocation.latitude + " / " + ambientWeatherMainPage.currentGeolocation.longitude);

                // fill global image array with data
                backgroundImage.imageDataArray = imageDataArray;
                ambientWeatherMainPage.currentImagedata = imageDataArray;

                // load weather data into component again with images
                if (ambientWeatherMainPage.currentWeatherdata !== undefined) {
                    weatherDashboard.setWeatherData(ambientWeatherMainPage.currentWeatherdata, ambientWeatherMainPage.currentImagedata);
                }

                // reset search radius (this may have been changed)
                ambientWeatherMainPage.currentLocationSearchRadius = Globals.locationSearchRadius;
            } else {
                // console.log("# No images found for location " + ambientWeatherMainPage.currentGeolocation.latitude + " / " + ambientWeatherMainPage.currentGeolocation.longitude);

                // extend search radius and search again
                ambientWeatherMainPage.currentLocationSearchRadius += Globals.locationSearchRadius;
                FlickrAPI.getFlickrSearchResults(ambientWeatherMainPage.currentGeolocation, ambientWeatherMainPage.currentWeatherdata, ambientWeatherMainPage.currentLocationSearchRadius, ambientWeatherMainPage);
            }
        }

        // weather data loaded from openweathermap
        onWeatherDataLoaded: {
            // store weather data in page component
            ambientWeatherMainPage.currentWeatherdata = weatherData;

            // load weather data into component
            weatherDashboard.setWeatherData(weatherData, ambientWeatherMainPage.currentImagedata);

            // load images for location
            FlickrAPI.getFlickrSearchResults(ambientWeatherMainPage.currentGeolocation, weatherData, ambientWeatherMainPage.currentLocationSearchRadius, ambientWeatherMainPage);
        }

        // attach components to page
        attachedObjects: [
            PositionSource {
                id: positionSource
                // desired interval between updates in milliseconds
                updateInterval: 10000

                // when position found (changed from null), update the location objects
                onPositionChanged: {
                    // store coordinates
                    ambientWeatherMainPage.currentGeolocation = positionSource.position.coordinate;

                    // check if location was really fixed
                    if (! ambientWeatherMainPage.currentGeolocation) {
                        // console.log("# Location could not be fixed");
                        weatherDashboard.weatherCondition = "Could not get your location :(";
                    } else {
                        console.debug("# Location found: " + ambientWeatherMainPage.currentGeolocation.latitude, ambientWeatherMainPage.currentGeolocation.longitude);

                        // stop location service
                        positionSource.stop();

                        // start loading weather data for location
                        weatherDashboard.weatherCondition = "Loading weather data..";
                        WeatherAPI.getWeatherData(ambientWeatherMainPage.currentGeolocation, ambientWeatherMainPage);
                    }
                }
            },
            OrientationHandler {
                id: orientationHandler
                onOrientationAboutToChange: {
                    if (orientation == UIOrientation.Portrait) {
                        backgroundImage.orientationChanged(DisplayInfo.width, DisplayInfo.height);
                        backgroundDashboard.preferredWidth = DisplayInfo.width;
                    } else if (orientation == UIOrientation.Landscape) {
                        backgroundImage.orientationChanged(DisplayInfo.height, DisplayInfo.width);
                        backgroundDashboard.preferredWidth = DisplayInfo.height;
                    }
                }
            }
        ]
    }

    // attach components to navigation pane
    attachedObjects: [
        ComponentDefinition {
            id: locationManagementComponent
            source: "pages/LocationManagement.qml"
        },
        // sheet for about page
        // this is used by the main menu about item
        Sheet {
            id: aboutSheet

            // attach a component for the about page
            attachedObjects: [
                ComponentDefinition {
                    id: aboutComponent
                    source: "sheets/About.qml"
                }
            ]
        },
        // sheet for settings page
        // this is used by the main menu about item
        Sheet {
            id: settingsSheet

            // attach a component for the about page
            attachedObjects: [
                ComponentDefinition {
                    id: settingsComponent
                    source: "sheets/Settings.qml"
                }
            ]
        },
        Invocation {
            id: rateAppLink
            query {
                mimeType: "application/x-bb-appworld"
                uri: "appworld://content/36698888"
            }
        }
    ]

    // application menu (top menu)
    Menu.definition: MenuDefinition {
        id: mainMenu

        // application about
        actions: [
            ActionItem {
                id: mainMenuAbout
                title: "About"
                imageSource: "asset:///images/icon_about.png"
                onTriggered: {
                    // create about sheet
                    var aboutPage = aboutComponent.createObject();
                    aboutSheet.setContent(aboutPage);
                    aboutSheet.open();
                }
            },
            // action for news sheet
            ActionItem {
                id: mainMenuSettings
                title: "Settings"
                imageSource: "asset:///images/icon_settings.png"
                onTriggered: {
                    // create settings sheet
                    var settingsPage = settingsComponent.createObject();
                    settingsSheet.setContent(settingsPage);
                    settingsSheet.open();
                }
            },
            // action for rate sheet
            ActionItem {
                id: mainMenuRate
                title: "Update & Rate"
                imageSource: "asset:///images/icon_bbworld.png"
                onTriggered: {
                    rateAppLink.trigger("bb.action.OPEN");
                }
            }
        ]
    }

    // destroy pages after use
    onPopTransitionEnded: {
        page.destroy();
    }
}