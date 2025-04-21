import { Hono } from 'hono'
import { cors } from 'hono/cors'

import { type Env, envVar } from './env'
import { getCcipRead } from './handlers/getCcipRead'

const app = new Hono<{ Bindings: Env }>()

app.use('*', cors())
app.get('/health', async (c) => c.json({ status: 'ok' }))
app.get('/v1/:sender/:data', async (c) => getCcipRead(c.req, c.env))

app.get('test', async (c) =>
  c.json({ value: envVar('ALCHEMY_API_KEY', c.env) })
)

export default app
