import { defineConfig } from 'vitepress'

export default defineConfig({
  title: 'mddir',
  description: 'Your web, saved locally — a markdown knowledge base for humans and agents.',
  base: '/mddir/',

  head: [
    ['link', { rel: 'icon', href: '/mddir/mddir-logo.png' }],
  ],

  themeConfig: {
    logo: '/mddir-logo.png',

    nav: [
      { text: 'Home', link: '/' },
      { text: 'Docs', link: '/introduction' },
    ],

    sidebar: [
      {
        text: 'Documentation',
        items: [
          { text: 'Introduction', link: '/introduction' },
          { text: 'Getting Started', link: '/getting-started' },
          { text: 'CLI Reference', link: '/cli-reference' },
          { text: 'Web UI', link: '/web-ui' },
          { text: 'Agent Integration', link: '/agent-integration' },
          { text: 'Configuration', link: '/configuration' },
          { text: 'Cookie Support', link: '/cookie-support' },
          { text: 'Data Storage', link: '/data-storage' },
        ],
      },
    ],

    socialLinks: [
      { icon: 'github', link: 'https://github.com/AliOsm/mddir' },
    ],

    editLink: {
      pattern: 'https://github.com/AliOsm/mddir/edit/main/docs/:path',
      text: 'Edit this page on GitHub',
    },

    search: {
      provider: 'local',
    },

    footer: {
      message: 'Released under the MIT License.',
      copyright: 'Copyright 2026 Ali Hamdi Ali Fadel',
    },
  },
})
