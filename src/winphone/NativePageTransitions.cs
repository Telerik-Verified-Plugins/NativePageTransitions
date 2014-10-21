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
using WPCordovaClassLib;
using Microsoft.Xna.Framework.Media;

namespace Cordova.Extension.Commands
{
    public class NativePageTransitions : BaseCommand
    {

        [DataContract]
        public class TransitionOptions
        {
            [DataMember(IsRequired = true, Name = "direction")]
            public string direction { get; set; }

            [DataMember(IsRequired = true, Name = "duration")]
            public int duration { get; set; }

            [DataMember(IsRequired = true, Name = "slowdownfactor")]
            public int slowdownfactor { get; set; }

            [DataMember(IsRequired = false, Name = "href")]
            public string href { get; set; }

            [DataMember(IsRequired = false, Name = "winphonedelay")]
            public int winphonedelay { get; set; }
        }

        private TransitionOptions transitionOptions = null;

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
                CordovaView cView = getCordovaView();
                WebBrowser browser = cView.Browser;

                // grab a screenshot
                WriteableBitmap bmp = new WriteableBitmap(browser, null);
                var width = (int)bmp.PixelWidth;
                var height = (int)bmp.PixelHeight;

                img = new Image();
                img.Source = bmp;

                img2 = new Image();
                img2.Source = bmp;

                // TODO wrap this animation stuff in a timeout (based on the winphonedelay)

                // image animation
                img2.RenderTransform = new TranslateTransform();
                DoubleAnimation imgAnimation = new DoubleAnimation();
                imgAnimation.Duration = TimeSpan.FromMilliseconds(transitionOptions.duration);

                string animationAxis = "X";
                double webviewAnimationFrom = 0;
                int screenshotSlowdownFactor = 1;
                int webviewSlowdownFactor = 1;
                int imgOrdering = 0;

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
                // TODO.. not overlayed yet..
                if (transitionOptions.href != null && transitionOptions.href != "" && transitionOptions.href != "null")
                {
                    String to = transitionOptions.href;
                    if (transitionOptions.href.StartsWith("#"))
                    {
                        to = "index.html" + to;
                    }
                    browser.Navigate(new Uri("www/" + to, UriKind.Relative));
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
                storyboard.Completed += animationCompleted;
                storyboard.Children.Add(imgAnimation);
                storyboard.Children.Add(webviewAnimation);

                this.Perform(delegate() {
                    // move the image below the webview if required
                    // TODO can't we update the z-index?
                    //if (imgOrdering == 0)
                    //{
                       // cView.LayoutRoot.Children.Insert(imgOrdering, img2);
                       cView.LayoutRoot.Children.Remove(img);
                    //}
                    storyboard.Begin();
                }, transitionOptions.winphonedelay);

                
                // TODO cleanup cView.LayoutRoot.Children.Add(img) via storyboard.Completed;

                /*
                DoubleAnimation myDoubleAnimation = new DoubleAnimation();
                myDoubleAnimation.From = 100;
                myDoubleAnimation.To = 300;
                myDoubleAnimation.Duration = new Duration(TimeSpan.FromMilliseconds(2000));

                // Configure the animation to target the button's Width property.
                Storyboard.SetTarget(myDoubleAnimation, img); //cView.LayoutRoot);
                Storyboard.SetTargetProperty(myDoubleAnimation, new PropertyPath("(UIElement.RenderTransform).(TranslateTransform.X)"));// new PropertyPath(ListBoxItem.FlowDirectionProperty));

                // Create a storyboard to contain the animation.
                Storyboard myHeightAnimatedButtonStoryboard = new Storyboard();
                myHeightAnimatedButtonStoryboard.Children.Add(myDoubleAnimation);
                myHeightAnimatedButtonStoryboard.Begin();
                */

        // this works fine for navigation.. and there is a browser.loadinfinished event I thing
//        browser.Source = new Uri("http://www.nu.nl");
        //bmp.Render(lbxDays, new TranslateTransform());
        /*
        using (var ms = new MemoryStream())
        {
            bmp.SaveJpeg(ms, width, height, 0, 100);
            ms.Seek(0, System.IO.SeekOrigin.Begin);
            var lib = new MediaLibrary();
            var dateStr = DateTime.Now.Ticks;
            var picture = lib.SavePicture(string.Format("screenshot" + dateStr + ".jpg"), ms);
            var task = new ShareMediaTask();
            //task.FilePath = picture.GetPath();
            //task.Show();
        }
         * */
     //   wbmp.SaveJpeg(isoStream2, wbmp.PixelWidth, wbmp.PixelHeight, 0, 100);

//        Bitmap bitmap = new Bitmap(browser.Width, browser.Height);
//        browser.DrawToBitmap(bitmap, new Rectangle(0, 0, browser.Width, browser.Height));
});


            

            // show the screenshot

            // load the new page in the webview
 
            // animate the screenshot offscreen
        }


        // clean up resources
        private void animationCompleted(object sender, EventArgs e)
        {
            (sender as Storyboard).Completed -= animationCompleted;
            Deployment.Current.Dispatcher.BeginInvoke(() =>
            {
                CordovaView cView = getCordovaView();
                cView.LayoutRoot.Children.Remove(img2);
            });
        }

        // for the flip animation:
        /*
        DoubleAnimation animation = new DoubleAnimation()
            {
                From = 0,
                Duration = TimeSpan.FromSeconds(0.6),
                To = 90 // 180
            };
            Storyboard.SetTarget(animation, SplashProjector);
            Storyboard.SetTargetProperty(animation, new PropertyPath("RotationY"));
        */

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