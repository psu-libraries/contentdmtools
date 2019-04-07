// JavaScript Document

// Global PSU Footer code, added by Karen Schwentner.
(function () {
  'use strict';
function libchat()   {
	  var head= document.getElementsByTagName('head')[0];
      var script= document.createElement('script');
      script.type= 'text/javascript';
      script.src= '//v2.libanswers.com/load_chat.php?hash=d51e38627705fc23934afaba4f563cc8';
      head.appendChild(script);
	   }

document.addEventListener('cdm-home-page:ready', libchat);
document.addEventListener('cdm-about-page:ready', libchat);
document.addEventListener('cdm-login-page:ready', libchat);
document.addEventListener('cdm-search-page:ready', libchat);
document.addEventListener('cdm-collection-landing-page:ready', libchat);
document.addEventListener('cdm-collection-search-page:ready', libchat);
document.addEventListener('cdm-advanced-search-page:ready', libchat);
document.addEventListener('cdm-item-page:ready', libchat);
document.addEventListener('cdm-custom-page:ready', libchat);
})();


(function () {
  'use strict';

function psuFooter(){
  const footerContainer = document.getElementsByClassName('Footer-footerWrapper');
  const psuFooterHTML = '<footer class="footer"><section class="row"><div class="footer__logo"><a href="http://www.psu.edu/"><img alt="Penn State University mark" src="https://libraries.psu.edu/sites/all/themes/custom/f5_psul/images/ul/psu_mark_footer.png"></a> </div><div class="footer__social"><h2>Connect with<br>Penn State Libraries</h2><ul><li><a href="https://www.facebook.com/psulibs">Facebook</a></li><li><a href="https://twitter.com/psulibs">Twitter</a></li><li><a href="https://www.instagram.com/psulibs/">Instagram</a></li></ul></div><div class="footer__meta"><h2>Penn State<br>University Libraries</h2><ul><li><a href="https://libraries.psu.edu">Libraries Home</a></li><li><a href="https://libraries.psu.edu/accessibility-help">Accessibility Help</a></li><li><a href="https://libraries.psu.edu/website-feedback">Website Feedback</a></li><li><a href="https://libraries.psu.edu/policies">Policies and Guidelines</a></li><li><a href="https://libraries.psu.edu/directory">Staff Directory</a></li></ul><ul><li>(814) 865-6368</li><li><a href="https://digital.libraries.psu.edu/digital/login">Staff Log In</a></li><li><a href="https://digital.libraries.psu.edu/digital/logout?targetUrl=/">Staff Log Out</a></li></ul></div><div class="footer__boiler"><p><a href="https://libraries.psu.edu/penn-state-libraries-copyright-statement">Libraries&apos; Copyright Statement</a> <br><a href="http://www.psu.edu/ur/legal.html">Legal Statements</a><br><a href="http://www.psu.edu/ur/hotline.html">Penn State Hotlines</a></p></div></section></footer><div class="ask" id="libchat_d51e38627705fc23934afaba4f563cc8"></div>';
  footerContainer[0].innerHTML = psuFooterHTML;
}

document.addEventListener('cdm-home-page:ready', psuFooter);
document.addEventListener('cdm-about-page:ready', psuFooter);
document.addEventListener('cdm-login-page:ready', psuFooter);
document.addEventListener('cdm-search-page:ready', psuFooter);
document.addEventListener('cdm-collection-landing-page:ready', psuFooter);
document.addEventListener('cdm-collection-search-page:ready', psuFooter);
document.addEventListener('cdm-advanced-search-page:ready', psuFooter);
document.addEventListener('cdm-item-page:ready', psuFooter);
document.addEventListener('cdm-custom-page:ready', psuFooter);
})();

(function () {
'use strict';
function changeLogoLink() {
     const headerLogo = document.querySelector('div.Header-logoHolder>div>a');
	 const newUrl = 'https://libraries.psu.edu/';
     headerLogo.href = newUrl;
     headerLogo.addEventListener('click', function(e) {
      this.href = newUrl;
      e.stopPropagation();
   });
  }

document.addEventListener('cdm-home-page:ready', changeLogoLink);
document.addEventListener('cdm-about-page:ready', changeLogoLink);
document.addEventListener('cdm-login-page:ready', changeLogoLink);
document.addEventListener('cdm-search-page:ready', changeLogoLink);
document.addEventListener('cdm-collection-landing-page:ready', changeLogoLink);
document.addEventListener('cdm-collection-search-page:ready', changeLogoLink);
document.addEventListener('cdm-advanced-search-page:ready', changeLogoLink);
document.addEventListener('cdm-item-page:ready', changeLogoLink);
document.addEventListener('cdm-custom-page:ready', changeLogoLink);
})();

// Enable grid view for visual resource collections.
// Added by Nathan Tallman, 2019-04-01; updated, 2019-04-03
(function () {
  'use strict';

  function gridClick(){
    document.querySelector('button[value="Grid View"]').click();
  }

  document.addEventListener('cdm-search-page:ready', function(e) {
    if ((e.detail.collectionId === 'arthist2') || (e.detail.collectionId === 'palmer') || (e.detail.collectionId === 'wwbldgs')) {
      gridClick();
    }
  });
  document.addEventListener('cdm-collection-search-page:ready', function(e) {
    if ((e.detail.collectionId === 'arthist2') || (e.detail.collectionId === 'palmer') || (e.detail.collectionId === 'wwbldgs')) {
      gridClick();
    }
  });
})();

// Matomo analytics, added by Nathan Tallman
// 2019-04-07: Fully working with pageviews and events (object interaction, downloads, printing)

    var _paq = window._paq || [];
    var u="https://analytics.libraries.psu.edu/matomo/";
    _paq.push(['setTrackerUrl', u+'matomo.php']);
    _paq.push(['setSiteId', '3']);
    var d=document, g=d.createElement('script'), s=d.getElementsByTagName('script')[0];
    g.type='text/javascript'; g.async=true; g.defer=true; g.src=u+'matomo.js'; s.parentNode.insertBefore(g,s);

  function genericPageView() {
    var pageTitle = document.querySelector('title').innerHTML;
    _paq.push(['deleteCustomVariables', 'page']);
    _paq.push(['setDocumentTitle', pageTitle]);
    _paq.push(['setGenerationTimeMs', 0]);
    _paq.push(['trackPageView']);
    _paq.push(['trackAllContentImpressions']);
    _paq.push(['enableLinkTracking']);
  }

  function itemPageView() {
    var pageTitle = document.querySelector('title').innerHTML;
    _paq.push(['deleteCustomVariables', 'page']);
    _paq.push(['setDocumentTitle', pageTitle]);
    _paq.push(['setGenerationTimeMs', 0]);
    _paq.push(['trackPageView']);
    _paq.push(['trackAllContentImpressions']);
    _paq.push(['enableLinkTracking']);

    if (document.querySelector('.ItemTitle-secondaryTitle')) {
      var title = document.querySelector('.ItemTitle-primaryTitle').innerText;
      var subTitle = document.querySelector('.ItemTitle-secondaryTitle').innerText;
      title = title + ': ' + subTitle;
    } else {
      var title = document.querySelector('.ItemTitle-primaryTitle').innerText;
    }

    // Events for opening and playing media
    if (document.querySelector('.ItemPDF-expandButton')) {
      document.querySelector('.ItemPDF-expandButton').addEventListener('click', function () {
        _paq.push(['trackEvent', 'Open', 'PDF', title]);
      }, false);
    }
    if (document.querySelector('.ItemImage-expandButton')) {
      document.querySelector('.ItemImage-expandButton').addEventListener('click', function () {
        _paq.push(['trackEvent', 'Open', 'Image', title]);
      }, false);
    }
    if (document.querySelector('video')) {
      document.querySelector('video').addEventListener("play", function () {
        _paq.push(['trackEvent', 'Play', 'Video', title]);
      }, false);
    }
    if (document.querySelector('audio')) {
      document.querySelector('audio').addEventListener("play", function () {
        _paq.push(['trackEvent', 'Play', 'Audio', title]);
      }, false);
    }

    // Events for downloading
    if (document.querySelector('#downloadsizemenu-side-bar')) {
      var menuItems = document.querySelectorAll('#downloadsizemenu-side-bar > li').length;
      if (menuItems == 5) {
         document.querySelectorAll('#downloadsizemenu-side-bar > li')[0].addEventListener('click', function() {
           _paq.push(['trackEvent', 'Download', 'Small', title]);
         }, false);
         document.querySelectorAll('#downloadsizemenu-side-bar > li')[1].addEventListener('click', function() {
           _paq.push(['trackEvent', 'Download', 'Medium', title]);
         }, false);
         document.querySelectorAll('#downloadsizemenu-side-bar > li')[2].addEventListener('click', function() {
           _paq.push(['trackEvent', 'Download', 'Large', title]);
         }, false);
         document.querySelectorAll('#downloadsizemenu-side-bar > li')[3].addEventListener('click', function() {
           _paq.push(['trackEvent', 'Download', 'Extra Large', title]);
         }, false);
         document.querySelectorAll('#downloadsizemenu-side-bar > li')[4].addEventListener('click', function() {
           _paq.push(['trackEvent', 'Download', 'Full Size', title]);
         }, false);
      }
      if (menuItems == 1) {
        document.querySelectorAll('#downloadsizemenu-side-bar > li')[0].addEventListener('click', function() {
          _paq.push(['trackEvent', 'Download', 'Item', title]);
        }, false);
      }
    }
    if (document.querySelector('.ItemDownload-itemDownloadButtonPadding')) {
      if (document.querySelectorAll('.ItemDownload-itemDownloadButtonPadding')) {
        var db = document.querySelectorAll('.ItemDownload-itemDownloadButtonPadding').length;
        for (var i = 0; i < db; i++) {
          document.querySelectorAll('.ItemDownload-itemDownloadButtonPadding')[i].addEventListener('click', function() {
            _paq.push(['trackEvent', 'Download', 'Object', title]);
          }, false);
        }
      } else {
        document.querySelector('.ItemDownload-itemDownloadButtonPadding').addEventListener('click', function() {
          _paq.push(['trackEvent', 'Download', 'Object', title]);
        }, false);
      }
    }

    // Events for printing
    if (document.querySelector('ul[aria-labelledby="print-dropdown-compound-item-side-bar"]')) {
      if (document.querySelectorAll('ul[aria-labelledby="print-dropdown-compound-item-side-bar"] > li')[0]) {
        document.querySelectorAll('ul[aria-labelledby="print-dropdown-compound-item-side-bar"] > li')[0].addEventListener('click', function() {
          _paq.push(['trackEvent', 'Print', 'Item', title]);
        }, false);
      }
      if (document.querySelectorAll('ul[aria-labelledby="print-dropdown-compound-item-side-bar"] > li')[1]) {
        document.querySelectorAll('ul[aria-labelledby="print-dropdown-compound-item-side-bar"] > li')[1].addEventListener('click', function() {
          _paq.push(['trackEvent', 'Print', 'Object', document.querySelector('.ItemTitle-primaryTitle').innerText]);
        }, false);
      }
    } else {
      if (document.querySelector('button[aria-label="Print"]')) {
        if (document.querySelectorAll('button[aria-label="Print"]')) {
          var pb = document.querySelectorAll('button[aria-label="Print"]').length;
          for (var l = 0; l < pb; l++) {
            document.querySelectorAll('button[aria-label="Print"]')[l].addEventListener('click', function() {
              _paq.push(['trackEvent', 'Print', 'Object', title]);
            }, false);
          }
        } else {
          document.querySelector('button[aria-label="Print"]').addEventListener('click', function() {
            _paq.push(['trackEvent', 'Print', 'Object', title]);
          }, false);
        }
      }
    }
  }

  function itemPageViewUpdate() {
    var pageTitle = document.querySelector('title').innerHTML;
    _paq.push(['deleteCustomVariables', 'page']);
    _paq.push(['setDocumentTitle', pageTitle]);
    _paq.push(['setGenerationTimeMs', 0]);
    _paq.push(['trackPageView']);
    _paq.push(['trackAllContentImpressions']);
    _paq.push(['enableLinkTracking']);

    if (document.querySelector('.ItemTitle-secondaryTitle')) {
      var title = document.querySelector('.ItemTitle-primaryTitle').innerText;
      var subTitle = document.querySelector('.ItemTitle-secondaryTitle').innerText;
      title = title + ': ' + subTitle;
    } else {
      var title = document.querySelector('.ItemTitle-primaryTitle').innerText;
    }
  }

  document.addEventListener('cdm-about-page:ready', genericPageView);
  document.addEventListener('cdm-login-page:ready', genericPageView);
  document.addEventListener('cdm-custom-page:ready', genericPageView);
  document.addEventListener('cdm-notfound-page:ready', genericPageView);
  document.addEventListener('cdm-collection-landing-page:ready', genericPageView);
  document.addEventListener('cdm-home-page:ready', genericPageView);
  document.addEventListener('cdm-home-page:update', genericPageView);
  document.addEventListener('cdm-search-page:ready', genericPageView);
  document.addEventListener('cdm-search-page:update', genericPageView);
  document.addEventListener('cdm-collection-search-page:ready', genericPageView);
  document.addEventListener('cdm-collection-search-page:update', genericPageView);
  document.addEventListener('cdm-advanced-search-page:ready', genericPageView);
  document.addEventListener('cdm-advanced-search-page:update', genericPageView);
  document.addEventListener('cdm-item-page:ready', itemPageView);
  document.addEventListener('cdm-item-page:update', itemPageViewUpdate);
