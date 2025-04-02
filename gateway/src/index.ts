import { getCcipRead } from './handlers/getCcipRead'

const port = process.env.PORT ? parseInt(process.env.PORT) : 3000
console.log(`Listening on port ${port}`)

Bun.serve({
  port,
  routes: {
    '/health': {
      GET: async () => {
        return Response.json({ status: 'ok' })
      },
    },
    '/v1/:sender/:data': {
      GET: async (req) => {
        const res = await getCcipRead(req)

        return Response.json(await res.json(), {
          status: res.status,
          headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
          },
        })
      },
    },
  },
  fetch() {
    return new Response('Not found', { status: 404 })
  },
})
