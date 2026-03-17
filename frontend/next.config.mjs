/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'ipfs.io' },
      { protocol: 'https', hostname: '**.ipfs.dweb.link' },
      // Add your renderer hostname here
      { protocol: 'https', hostname: 'api.yourproject.com' },
      { protocol: 'http',  hostname: 'localhost' },
    ],
  },
}

export default nextConfig
