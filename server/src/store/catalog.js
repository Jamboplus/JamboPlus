/**
 * App catalog — single source of truth for the JamboPlus AppStore.
 *
 * `playUrl` values are the exact Google Play listing URLs. Every install /
 * redirect in the store resolves to one of these and nothing else (no URL is
 * ever taken from user input), so a promo link can never send a user to the
 * wrong app.
 */

const APPS = [
  {
    slug: 'jamboplus',
    aliases: ['jambo-plus', 'jambo'],
    packageId: 'com.jamboplus',
    name: 'JamboPlus',
    category: { sw: 'Burudani', en: 'Entertainment' },
    playUrl: 'https://play.google.com/store/apps/details?id=com.jamboplus&pcampaignid=web_share',
    accent: '#1e6bff',
    accentText: '#ffffff',
    tagline: {
      sw: 'Tazama mpira live, movies na michezo kwenye simu yako.',
      en: 'Stream live football, movies, TV and sports on your phone.',
    },
    about: {
      sw: 'JamboPlus ni app ya kisasa ya burudani inayokuleta karibu na mpira wa miguu, muziki na maudhui mbalimbali. Rahisi kutumia, haraka na imeundwa kwa simu za Android.',
      en: 'JamboPlus is a modern entertainment app that brings you closer to football, music and a variety of content. Simple, fast and built for Android phones.',
    },
    features: {
      sw: ['Mpira wa miguu live', 'Muziki na burudani mbalimbali', 'Muonekano safi na wa kisasa', 'Kasi nzuri na urambazaji rahisi'],
      en: ['Live football', 'Music and entertainment', 'Clean, modern interface', 'Fast performance, easy navigation'],
    },
  },
  {
    slug: 'washatv',
    aliases: ['washa-tv', 'washa'],
    packageId: 'com.washatv',
    name: 'Washa TV',
    category: { sw: 'Burudani', en: 'Entertainment' },
    playUrl: 'https://play.google.com/store/apps/details?id=com.washatv&pcampaignid=web_share',
    accent: '#ff3d71',
    accentText: '#ffffff',
    tagline: {
      sw: 'Tazama mpira, movies, katuni na TV live popote ulipo.',
      en: 'Watch football, movies, cartoons and live TV wherever you are.',
    },
    about: {
      sw: 'Washa TV ni application ya kisasa ya live streaming inayokuwezesha kutazama mpira wa miguu, movies, burudani, katuni, habari pamoja na channel mbalimbali za TV moja kwa moja kupitia simu yako.',
      en: 'Washa TV is a modern live streaming app for watching football, movies, entertainment, cartoons, news and many TV channels straight from your phone.',
    },
    features: {
      sw: ['Kuangalia mpira live', 'Movies na channel za burudani', 'Katuni kwa watoto', 'Habari na sports channels', 'Channel za bure na premium'],
      en: ['Watch football live', 'Movies and entertainment channels', 'Cartoons for kids', 'News and sports channels', 'Free and premium channels'],
    },
  },
  {
    slug: 'leotena',
    aliases: ['leotena-tv', 'leo-tena', 'leo-tena-tv', 'leotenatv'],
    packageId: 'com.ghettodevelopers.leotena',
    name: 'LeoTena TV',
    category: { sw: 'Burudani', en: 'Entertainment' },
    playUrl: 'https://play.google.com/store/apps/details?id=com.ghettodevelopers.leotena&pcampaignid=web_share',
    accent: '#22e000',
    accentText: '#04210a',
    tagline: {
      sw: 'Burudika na movies, pamoja na tamthilia za Kibongo.',
      en: 'Enjoy movies, series and Bongo dramas anytime.',
    },
    about: {
      sw: 'LeoTena ina maktaba kubwa ya highlights, movies, tamthilia, TV shows, anime na zaidi! Tazama kadri unavyotaka, wakati wowote.',
      en: 'LeoTena has a broad library of highlights, films, drama series, TV shows, anime and more. Watch as much as you want, whenever you want.',
    },
    features: {
      sw: ['Movies na tamthilia za Kibongo', 'TV shows na anime', 'Highlights za mpira', 'Tazama wakati wowote'],
      en: ['Movies and Bongo dramas', 'TV shows and anime', 'Match highlights', 'Watch any time'],
    },
  },
];

const BY_SLUG = new Map();
for (const app of APPS) {
  BY_SLUG.set(app.slug, app);
  for (const alias of app.aliases) BY_SLUG.set(alias, app);
}

/** Look up an app by slug/alias (case-insensitive). Returns null if unknown. */
function findApp(slug) {
  if (typeof slug !== 'string') return null;
  return BY_SLUG.get(slug.trim().toLowerCase()) || null;
}

module.exports = { APPS, findApp };
