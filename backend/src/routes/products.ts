import { Router } from 'express';
import type { RequestHandler } from 'express';

import { authenticate, requireAdmin } from '../middlewares/auth.js';
import * as productService from '../services/product-service.js';

export const productsRouter = Router();

const list: RequestHandler = async (request, response) => {
  const branchId = productService.parseBranchFilter(request.query.branch_id);
  response.json({ data: await productService.listProducts(branchId) });
};

const options: RequestHandler = async (_request, response) => {
  response.json({ data: await productService.listOptions() });
};

const create: RequestHandler = async (request, response) => {
  response
    .status(201)
    .json({ data: await productService.createProduct(request.body) });
};

const move: RequestHandler = async (request, response) => {
  const productId = productService.parseProductId(request.params.productId);
  response.json({
    data: await productService.moveProduct(productId, request.body),
  });
};

productsRouter.get('/', authenticate, list);
productsRouter.get('/options', ...requireAdmin, options);
productsRouter.post('/', ...requireAdmin, create);
productsRouter.patch('/:productId/location', ...requireAdmin, move);
