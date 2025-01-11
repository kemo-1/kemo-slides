import Koa from 'koa'
import koaStatic from 'koa-static'

const koa = new Koa()
koa.use(koaStatic('./'))
koa.listen(8989)