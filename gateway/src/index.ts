import { getCcipRead } from './handlers/getCcipRead'

Bun.serve({
  port: 3000,
  routes: {
    '/v1/:sender/:data': {
      GET: (req) => getCcipRead(req),
    },
  },
  fetch() {
    return new Response('Not found', { status: 404 })
  },
})
