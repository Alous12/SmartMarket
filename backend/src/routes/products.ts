import { Router } from 'express';
import type { RequestHandler } from 'express';

import { authenticate, identityOf, requireAdmin } from '../middlewares/auth.js';
import * as productService from '../services/product-service.js';

export const productsRouter = Router();

const list: RequestHandler = async (request, response) => {
  const branchId = productService.parseBranchFilter(request.query.branch_id);
  response.json({
    data: await productService.listProductsFor(identityOf(response), branchId),
  });
};

const options: RequestHandler = async (_request, response) => {
  response.json({
    data: await productService.listOptions(identityOf(response).userId),
  });
};

const create: RequestHandler = async (request, response) => {
  response.status(201).json({
    data: await productService.createProduct(
      request.body,
      identityOf(response).userId,
    ),
  });
};

const move: RequestHandler = async (request, response) => {
  const productId = productService.parseProductId(request.params.productId);
  response.json({
    data: await productService.moveProduct(
      productId,
      request.body,
      identityOf(response).userId,
    ),
  });
};

const remove: RequestHandler = async (request, response) => {
  const productId = productService.parseProductId(request.params.productId);
  await productService.removeProduct(productId, identityOf(response).userId);
  response.status(204).end();
};

const slots: RequestHandler = async (request, response) => {
  const branchId = productService.parseBranchFilter(request.query.branch_id);
  response.json({
    data: await productService.listSlotsFor(identityOf(response), branchId),
  });
};

const moveSlot: RequestHandler = async (request, response) => {
  response.json({
    data: await productService.moveSlot(request.body, identityOf(response).userId),
  });
};

const createInSlot: RequestHandler = async (request, response) => {
  const code = String(request.params.slotCode ?? '');
  response.status(201).json({
    data: await productService.createInSlot(
      code,
      request.body,
      identityOf(response).userId,
    ),
  });
};

const update: RequestHandler = async (request, response) => {
  const productId = productService.parseProductId(request.params.productId);
  response.json({
    data: await productService.updateProduct(
      productId,
      request.body,
      identityOf(response).userId,
    ),
  });
};

productsRouter.get('/', authenticate, list);
productsRouter.get('/options', ...requireAdmin, options);
productsRouter.get('/slots', authenticate, slots);
productsRouter.post('/slots/move', ...requireAdmin, moveSlot);
productsRouter.post('/slots/:slotCode/product', ...requireAdmin, createInSlot);
productsRouter.post('/', ...requireAdmin, create);
productsRouter.patch('/:productId', ...requireAdmin, update);
productsRouter.patch('/:productId/location', ...requireAdmin, move);
productsRouter.delete('/:productId', ...requireAdmin, remove);
