using Microsoft.Phone.Tasks;
using Microsoft.Phone.Controls;
using WPCordovaClassLib.Cordova;
using WPCordovaClassLib.Cordova.Commands;
using WPCordovaClassLib.Cordova.JSON;
using System.Runtime.Serialization;
using System;
using System.ComponentModel;
using System.IO;
using System.Threading;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Imaging;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Navigation;
using WPCordovaClassLib;
using Microsoft.Xna.Framework.Media;

namespace Cordova.Extension.Commands
{
    public class NativePageTransitions : BaseCommand
    {

        public NativePageTransitions()
        {
            cView = getCordovaView();
            browser = cView.Browser;
            //browser.Navigated += Browser_Navigated;
            //browser.Navigating += Browser_Navigating;
            img = new Image();
        }

        [DataContract]
        public class TransitionOptions
        {
            [DataMember(IsRequired = true, Name = "direction")]
            public string direction { get; set; }

            [DataMember(IsRequired = true, Name = "duration")]
            public int duration { get; set; }

            [DataMember(IsRequired = false, Name = "slowdownfactor")]
            public int slowdownfactor { get; set; }

            [DataMember(IsRequired = false, Name = "href")]
            public string href { get; set; }

            [DataMember(IsRequired = false, Name = "winphonedelay")]
            public int winphonedelay { get; set; }
        }

        private CordovaView cView;
        private WebBrowser browser;
        private TransitionOptions transitionOptions;
        private Image img;
        private Image img2;

        public void slide(string options)
        {
            try
            {
                String jsonOptions = JsonHelper.Deserialize<string[]>(options)[0];
                transitionOptions = JsonHelper.Deserialize<TransitionOptions>(jsonOptions);
            }
            catch (Exception)
            {
                DispatchCommandResult(new PluginResult(PluginResult.Status.JSON_EXCEPTION));
                return;
            }

            Deployment.Current.Dispatcher.BeginInvoke(() =>
            {
                // grab a screenshot
                WriteableBitmap bmp = new WriteableBitmap(browser, null);
                var width = (int)bmp.PixelWidth;
                var height = (int)bmp.PixelHeight;

                img.Source = bmp;

                img2 = new Image();
                img2.Source = bmp;

                // image animation
                img2.RenderTransform = new TranslateTransform();
                DoubleAnimation imgAnimation = new DoubleAnimation();
                imgAnimation.Duration = TimeSpan.FromMilliseconds(transitionOptions.duration);

                string animationAxis = "X";
                double webviewAnimationFrom = 0;
                int screenshotSlowdownFactor = 1;
                int webviewSlowdownFactor = 1;
                int imgOrdering = 0;

                if (transitionOptions.slowdownfactor < 0) {
                  transitionOptions.slowdownfactor = 1000;
                }

                if (transitionOptions.direction == "left")
                {
                    screenshotSlowdownFactor = transitionOptions.slowdownfactor;
                    webviewAnimationFrom = width;
                    imgAnimation.To = -width / screenshotSlowdownFactor; // Application.Current.Host.Content.ActualWidth;
                }
                else if (transitionOptions.direction == "right")
                {
                    webviewSlowdownFactor = transitionOptions.slowdownfactor;
                    webviewAnimationFrom = -width;
                    imgAnimation.To = width; // Application.Current.Host.Content.ActualWidth;
                    imgOrdering = 1;
                }
                else if (transitionOptions.direction == "up")
                {
                    animationAxis = "Y";
                    screenshotSlowdownFactor = transitionOptions.slowdownfactor;
                    webviewAnimationFrom = height;
                    imgAnimation.To = -height / screenshotSlowdownFactor; // Application.Current.Host.Content.ActualHeight;
                }
                else if (transitionOptions.direction == "down")
                {
                    animationAxis = "Y";
                    webviewSlowdownFactor = transitionOptions.slowdownfactor;
                    webviewAnimationFrom = -height;
                    imgAnimation.To = height; // Application.Current.Host.Content.ActualHeight;
                    imgOrdering = 1;
                }

                // inserting the image at index 0 makes it appear below the webview,
                // but we need to set it to 1 first so the webview is hidden and can be updated
                cView.LayoutRoot.Children.Insert(1, img);
                cView.LayoutRoot.Children.Insert(imgOrdering, img2);


                // now load the new content
                if (transitionOptions.href != null && transitionOptions.href != "" && transitionOptions.href != "null")
                {
                    String to = transitionOptions.href;
                    Uri currenturi = browser.Source;
                    string path = currenturi.OriginalString;
                    if (to.StartsWith("#"))
                    {
                        if (path.StartsWith("//"))
                        {
                            path = path.Substring(2);
                        }
﻿                        if (path.Contains("#"))
                         {
                             path = path.Substring(0, path.IndexOf("#"));
                         }
                         to = path + to;
                    }
                    else
                    {
                      	to = path.Substring(0, path.LastIndexOf('/')+1) + to;
                    }
                    browser.Navigate(new Uri(to, UriKind.RelativeOrAbsolute));
                }

                Storyboard.SetTarget(imgAnimation, img2);
                Storyboard.SetTargetProperty(imgAnimation, new PropertyPath("(UIElement.RenderTransform).(TranslateTransform." + animationAxis + ")"));


                browser.RenderTransform = new TranslateTransform();
                DoubleAnimation webviewAnimation = new DoubleAnimation();
                webviewAnimation.Duration = TimeSpan.FromMilliseconds(transitionOptions.duration);
                webviewAnimation.From = webviewAnimationFrom / webviewSlowdownFactor;
                webviewAnimation.To = 0;
                Storyboard.SetTarget(webviewAnimation, browser);
                Storyboard.SetTargetProperty(webviewAnimation, new PropertyPath("(UIElement.RenderTransform).(TranslateTransform." + animationAxis + ")"));


                Storyboard storyboard = new Storyboard();
                storyboard.Completed += slideAnimationCompleted;
                storyboard.Children.Add(imgAnimation);
                storyboard.Children.Add(webviewAnimation);

                this.Perform(delegate()
                {
                    cView.LayoutRoot.Children.Remove(img);
                    storyboard.Begin();
                }, transitionOptions.winphonedelay);
            });
        }


        public void flip(string options)
        {
            try
            {
                String jsonOptions = JsonHelper.Deserialize<string[]>(options)[0];
                transitionOptions = JsonHelper.Deserialize<TransitionOptions>(jsonOptions);
            }
            catch (Exception)
            {
                DispatchCommandResult(new PluginResult(PluginResult.Status.JSON_EXCEPTION));
                return;
            }

            Deployment.Current.Dispatcher.BeginInvoke(() =>
            {
                // grab a screenshot
                WriteableBitmap bmp = new WriteableBitmap(browser, null);

                img2 = new Image();
                img2.Source = bmp;

                int direction = 1;
                DependencyProperty property = PlaneProjection.RotationYProperty;

                if (transitionOptions.direction == "right")
                {
                    direction = -1;
                }
                else if (transitionOptions.direction == "up")
                {
                    property = PlaneProjection.RotationXProperty;
                    direction = -1;
                }
                else if (transitionOptions.direction == "down")
                {
                    property = PlaneProjection.RotationXProperty;
                }

                // Insert the screenshot above the webview (index 1)
                cView.LayoutRoot.Children.Insert(1, img2);

                // now load the new content
                if (transitionOptions.href != null && transitionOptions.href != "" && transitionOptions.href != "null")
                {
                    String to = transitionOptions.href;
                    Uri currenturi = browser.Source;
                    string path = currenturi.OriginalString;
                    if (to.StartsWith("#"))
                    {
                        if (path.StartsWith("//"))
                        {
                            path = path.Substring(2);
                        }
﻿                        if (path.Contains("#"))
                         {
                             path = path.Substring(0, path.IndexOf("#"));
                         }
                         to = path + to;
                    }
                    else
                    {
                      	to = path.Substring(0, path.LastIndexOf('/')+1) + to;
                    }
                    browser.Navigate(new Uri(to, UriKind.RelativeOrAbsolute));
                }

                TimeSpan duration = TimeSpan.FromMilliseconds(transitionOptions.duration);
                Storyboard sb = new Storyboard();
                sb.Completed += flipAnimationCompleted;

                // animation for the screenshot
                DoubleAnimation imgAnimation = new DoubleAnimation()
                {
                    From = 0,
                    To = direction * 180,
                    Duration = new Duration(duration)
                };
                Storyboard.SetTargetProperty(imgAnimation, new PropertyPath(property));
                img2.Projection = new PlaneProjection();
                Storyboard.SetTarget(imgAnimation, img2.Projection);
                sb.Children.Add(imgAnimation);

                // animation for the webview
                DoubleAnimation webviewAnimation = new DoubleAnimation()
                {
                    From = direction * -180,
                    To = 0,
                    Duration = new Duration(duration)
                };
                Storyboard.SetTargetProperty(webviewAnimation, new PropertyPath(property));
                browser.Projection = new PlaneProjection();
                Storyboard.SetTarget(webviewAnimation, browser.Projection);
                sb.Children.Add(webviewAnimation);

                // perform the transition after the specified delay
                this.Perform(delegate()
                {
                    // remove the image halfway down the transition so we don't see the back of the image instead of the webview
                    this.Perform(delegate()
                    {
                        Deployment.Current.Dispatcher.BeginInvoke(() =>
                        {
                            CordovaView cView2 = getCordovaView();
                            cView2.LayoutRoot.Children.Remove(img2);
                        });
                    }, transitionOptions.duration / 2);

                    sb.Begin();
                }, transitionOptions.winphonedelay);
            });
        }

        // clean up resources
        private void slideAnimationCompleted(object sender, EventArgs e)
        {
            (sender as Storyboard).Completed -= slideAnimationCompleted;
            Deployment.Current.Dispatcher.BeginInvoke(() =>
            {
                CordovaView cView = getCordovaView();
                cView.LayoutRoot.Children.Remove(img2);
            });
            DispatchCommandResult(new PluginResult(PluginResult.Status.OK));
        }

        private void flipAnimationCompleted(object sender, EventArgs e)
        {
            (sender as Storyboard).Completed -= flipAnimationCompleted;
            DispatchCommandResult(new PluginResult(PluginResult.Status.OK));
        }

        void Browser_Navigated(object sender, NavigationEventArgs e)
        {
        }

        void Browser_Navigating(object sender, NavigationEventArgs e)
        {
        }

        private CordovaView getCordovaView()
        {
            PhoneApplicationFrame frame = (PhoneApplicationFrame)Application.Current.RootVisual;
            PhoneApplicationPage page = (PhoneApplicationPage)frame.Content;
            return (CordovaView)page.FindName("CordovaView");
        }

        private void Perform(Action myMethod, int delayInMilliseconds)
        {
            BackgroundWorker worker = new BackgroundWorker();
            worker.DoWork += (s, e) => Thread.Sleep(delayInMilliseconds);
            worker.RunWorkerCompleted += (s, e) => myMethod.Invoke();
            worker.RunWorkerAsync();
        }
    }
}