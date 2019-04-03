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
  const psuFooterHTML = '<footer class="footer"><section class="row"><div class="footer__logo"><a href="http://www.psu.edu/"><img alt="Penn State University mark" src="https://libraries.psu.edu/sites/all/themes/custom/f5_psul/images/ul/psu_mark_footer.png"></a> </div><div class="footer__social"><h2>Connect with<br>Penn State Libraries</h2><ul><li><a href="https://www.facebook.com/psulibs">Facebook</a></li><li><a href="https://twitter.com/psulibs">Twitter</a></li><li><a href="https://www.instagram.com/psulibs/">Instagram</a></li></ul></div><div class="footer__meta"><h2>Penn State<br>University Libraries</h2><ul><li><a href="https://libraries.psu.edu">Libraries Home</a></li><li><a href="https://libraries.psu.edu/accessibility-help">Accessibility Help</a></li><li><a href="https://libraries.psu.edu/website-feedback">Website Feedback</a></li><li><a href="https://libraries.psu.edu/policies">Policies and Guidelines</a></li><li><a href="https://libraries.psu.edu/directory">Staff Directory</a></li></ul><ul><li>(814) 865-6368</li></ul></div><div class="footer__boiler"><p><a href="https://libraries.psu.edu/penn-state-libraries-copyright-statement">Libraries&apos; Copyright Statement</a> <br><a href="http://www.psu.edu/ur/legal.html">Legal Statements</a><br><a href="http://www.psu.edu/ur/hotline.html">Penn State Hotlines</a></p></div></section></footer><div class="ask" id="libchat_d51e38627705fc23934afaba4f563cc8"></div>';
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


// Matomo analytics, added by Nathan Tallman, 2019-03-14
(function () {
  'use strict';
function pageView() {
  var _paq = _paq || [];
  _paq.push(['trackPageView']);
  _paq.push(['enableLinkTracking']);
  (function() {
    var u="https://analytics.libraries.psu.edu/matomo/";
    _paq.push(['setTrackerUrl', u+'piwik.php']);
    _paq.push(['setSiteId', '3']);
    var d=document, g=d.createElement('script'), s=d.getElementsByTagName('script')[0];
    g.type='text/javascript'; g.async=true; g.defer=true; g.src=u+'piwik.js'; s.parentNode.insertBefore(g,s);
  })();
}
document.addEventListener('cdm-home-page:ready', pageView);
document.addEventListener('cdm-about-page:ready', pageView);
document.addEventListener('cdm-login-page:ready', pageView);
document.addEventListener('cdm-search-page:ready', pageView);
document.addEventListener('cdm-collection-landing-page:ready', pageView);
document.addEventListener('cdm-collection-search-page:ready', pageView);
document.addEventListener('cdm-advanced-search-page:ready', pageView);
document.addEventListener('cdm-item-page:ready', pageView);
document.addEventListener('cdm-custom-page:ready', pageView);
document.addEventListener('cdm-notfound-page:ready', pageView);
})();
