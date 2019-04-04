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

// Matomo analytics, added by Nathan Tallman, January 2019

    var _paq = window._paq || [];
    _paq.push(['trackPageView']);
    _paq.push(['enableLinkTracking']);

    var u="https://analytics.libraries.psu.edu/matomo/";
    _paq.push(['setTrackerUrl', u+'matomo.php']);
    _paq.push(['setSiteId', '3']);
    var d=document, g=d.createElement('script'), s=d.getElementsByTagName('script')[0];g.type='text/javascript'; g.async=true; g.defer=true; g.src=u+'matomo.js'; s.parentNode.insertBefore(g,s);

document.addEventListener('cdm-home-page:ready', function() {
  // remove all previously assigned custom variables, requires Matomo (formerly Piwik) 3.0.2
  _paq.push(['deleteCustomVariables', 'page']);
  _paq.push(['setGenerationTimeMs', 0]);
  _paq.push(['trackPageView']);

  // make Matomo aware of newly added content
  var content = document.getElementById('root');
  _paq.push(['MediaAnalytics::scanForMedia', content]);
  _paq.push(['FormAnalytics::scanForForms', content]);
  _paq.push(['trackContentImpressionsWithinNode', content]);
  _paq.push(['enableLinkTracking']);
});
document.addEventListener('cdm-home-page:update', function() {
  // remove all previously assigned custom variables, requires Matomo (formerly Piwik) 3.0.2
  _paq.push(['deleteCustomVariables', 'page']);
  _paq.push(['setGenerationTimeMs', 0]);
  _paq.push(['trackPageView']);

  // make Matomo aware of newly added content
  var content = document.getElementById('root');
  _paq.push(['MediaAnalytics::scanForMedia', content]);
  _paq.push(['FormAnalytics::scanForForms', content]);
  _paq.push(['trackContentImpressionsWithinNode', content]);
  _paq.push(['enableLinkTracking']);
});
document.addEventListener('cdm-about-page:ready', function() {
  // remove all previously assigned custom variables, requires Matomo (formerly Piwik) 3.0.2
  _paq.push(['deleteCustomVariables', 'page']);
  _paq.push(['setGenerationTimeMs', 0]);
  _paq.push(['trackPageView']);

  // make Matomo aware of newly added content
  var content = document.getElementById('root');
  _paq.push(['MediaAnalytics::scanForMedia', content]);
  _paq.push(['FormAnalytics::scanForForms', content]);
  _paq.push(['trackContentImpressionsWithinNode', content]);
  _paq.push(['enableLinkTracking']);
});
document.addEventListener('cdm-login-page:ready', function() {
  // remove all previously assigned custom variables, requires Matomo (formerly Piwik) 3.0.2
  _paq.push(['deleteCustomVariables', 'page']);
  _paq.push(['setGenerationTimeMs', 0]);
  _paq.push(['trackPageView']);

  // make Matomo aware of newly added content
  var content = document.getElementById('root');
  _paq.push(['MediaAnalytics::scanForMedia', content]);
  _paq.push(['FormAnalytics::scanForForms', content]);
  _paq.push(['trackContentImpressionsWithinNode', content]);
  _paq.push(['enableLinkTracking']);
});
document.addEventListener('cdm-search-page:ready', function() {
  // remove all previously assigned custom variables, requires Matomo (formerly Piwik) 3.0.2
  _paq.push(['deleteCustomVariables', 'page']);
  _paq.push(['setGenerationTimeMs', 0]);
  _paq.push(['trackPageView']);

  // make Matomo aware of newly added content
  var content = document.getElementById('root');
  _paq.push(['MediaAnalytics::scanForMedia', content]);
  _paq.push(['FormAnalytics::scanForForms', content]);
  _paq.push(['trackContentImpressionsWithinNode', content]);
  _paq.push(['enableLinkTracking']);
});
document.addEventListener('cdm-search-page:update', function() {
  // remove all previously assigned custom variables, requires Matomo (formerly Piwik) 3.0.2
  _paq.push(['deleteCustomVariables', 'page']);
  _paq.push(['setGenerationTimeMs', 0]);
  _paq.push(['trackPageView']);

  // make Matomo aware of newly added content
  var content = document.getElementById('root');
  _paq.push(['MediaAnalytics::scanForMedia', content]);
  _paq.push(['FormAnalytics::scanForForms', content]);
  _paq.push(['trackContentImpressionsWithinNode', content]);
  _paq.push(['enableLinkTracking']);
});
document.addEventListener('cdm-collection-landing-page:ready', function() {
  // remove all previously assigned custom variables, requires Matomo (formerly Piwik) 3.0.2
  _paq.push(['deleteCustomVariables', 'page']);
  _paq.push(['setGenerationTimeMs', 0]);
  _paq.push(['trackPageView']);

  // make Matomo aware of newly added content
  var content = document.getElementById('root');
  _paq.push(['MediaAnalytics::scanForMedia', content]);
  _paq.push(['FormAnalytics::scanForForms', content]);
  _paq.push(['trackContentImpressionsWithinNode', content]);
  _paq.push(['enableLinkTracking']);
});
document.addEventListener('cdm-collection-search-page:ready', function() {
  // remove all previously assigned custom variables, requires Matomo (formerly Piwik) 3.0.2
  _paq.push(['deleteCustomVariables', 'page']);
  _paq.push(['setGenerationTimeMs', 0]);
  _paq.push(['trackPageView']);

  // make Matomo aware of newly added content
  var content = document.getElementById('root');
  _paq.push(['MediaAnalytics::scanForMedia', content]);
  _paq.push(['FormAnalytics::scanForForms', content]);
  _paq.push(['trackContentImpressionsWithinNode', content]);
  _paq.push(['enableLinkTracking']);
});
document.addEventListener('cdm-collection-search-page:update', function() {
  // remove all previously assigned custom variables, requires Matomo (formerly Piwik) 3.0.2
  _paq.push(['deleteCustomVariables', 'page']);
  _paq.push(['setGenerationTimeMs', 0]);
  _paq.push(['trackPageView']);

  // make Matomo aware of newly added content
  var content = document.getElementById('root');
  _paq.push(['MediaAnalytics::scanForMedia', content]);
  _paq.push(['FormAnalytics::scanForForms', content]);
  _paq.push(['trackContentImpressionsWithinNode', content]);
  _paq.push(['enableLinkTracking']);
});
document.addEventListener('cdm-advanced-search-page:ready', function() {
  // remove all previously assigned custom variables, requires Matomo (formerly Piwik) 3.0.2
  _paq.push(['deleteCustomVariables', 'page']);
  _paq.push(['setGenerationTimeMs', 0]);
  _paq.push(['trackPageView']);

  // make Matomo aware of newly added content
  var content = document.getElementById('root');
  _paq.push(['MediaAnalytics::scanForMedia', content]);
  _paq.push(['FormAnalytics::scanForForms', content]);
  _paq.push(['trackContentImpressionsWithinNode', content]);
  _paq.push(['enableLinkTracking']);
});
document.addEventListener('cdm-advanced-search-page:update', function() {
  // remove all previously assigned custom variables, requires Matomo (formerly Piwik) 3.0.2
  _paq.push(['deleteCustomVariables', 'page']);
  _paq.push(['setGenerationTimeMs', 0]);
  _paq.push(['trackPageView']);

  // make Matomo aware of newly added content
  var content = document.getElementById('root');
  _paq.push(['MediaAnalytics::scanForMedia', content]);
  _paq.push(['FormAnalytics::scanForForms', content]);
  _paq.push(['trackContentImpressionsWithinNode', content]);
  _paq.push(['enableLinkTracking']);
});
document.addEventListener('cdm-item-page:ready', function() {
  // remove all previously assigned custom variables, requires Matomo (formerly Piwik) 3.0.2
  _paq.push(['deleteCustomVariables', 'page']);
  _paq.push(['setGenerationTimeMs', 0]);
  _paq.push(['trackPageView']);

  // make Matomo aware of newly added content
  var content = document.getElementById('root');
  _paq.push(['MediaAnalytics::scanForMedia', content]);
  _paq.push(['FormAnalytics::scanForForms', content]);
  _paq.push(['trackContentImpressionsWithinNode', content]);
  _paq.push(['enableLinkTracking']);
});
document.addEventListener('cdm-item-page:update', function() {
  // remove all previously assigned custom variables, requires Matomo (formerly Piwik) 3.0.2
  _paq.push(['deleteCustomVariables', 'page']);
  _paq.push(['setGenerationTimeMs', 0]);
  _paq.push(['trackPageView']);

  // make Matomo aware of newly added content
  var content = document.getElementById('root');
  _paq.push(['MediaAnalytics::scanForMedia', content]);
  _paq.push(['FormAnalytics::scanForForms', content]);
  _paq.push(['trackContentImpressionsWithinNode', content]);
  _paq.push(['enableLinkTracking']);
});
document.addEventListener('cdm-custom-page:ready', function() {
  // remove all previously assigned custom variables, requires Matomo (formerly Piwik) 3.0.2
  _paq.push(['deleteCustomVariables', 'page']);
  _paq.push(['setGenerationTimeMs', 0]);
  _paq.push(['trackPageView']);

  // make Matomo aware of newly added content
  var content = document.getElementById('root');
  _paq.push(['MediaAnalytics::scanForMedia', content]);
  _paq.push(['FormAnalytics::scanForForms', content]);
  _paq.push(['trackContentImpressionsWithinNode', content]);
  _paq.push(['enableLinkTracking']);
});
document.addEventListener('cdm-notfound-page:ready', function() {
  // remove all previously assigned custom variables, requires Matomo (formerly Piwik) 3.0.2
  _paq.push(['deleteCustomVariables', 'page']);
  _paq.push(['setGenerationTimeMs', 0]);
  _paq.push(['trackPageView']);

  // make Matomo aware of newly added content
  var content = document.getElementById('root');
  _paq.push(['MediaAnalytics::scanForMedia', content]);
  _paq.push(['FormAnalytics::scanForForms', content]);
  _paq.push(['trackContentImpressionsWithinNode', content]);
  _paq.push(['enableLinkTracking']);
});
