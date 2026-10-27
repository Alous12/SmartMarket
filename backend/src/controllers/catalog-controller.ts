import type { RequestHandler } from 'express';

import * as catalogService from '../services/catalog-service.js';

const branchId = (value: unknown) => catalogService.parseId(value, 'branchId');

export const listBranches: RequestHandler = async (_request, response) => {
  response.json({ data: await catalogService.listBranches() });
};

export const getBranch: RequestHandler = async (request, response) => {
  response.json({
    data: await catalogService.getBranch(branchId(request.params.branchId)),
  });
};

export const listPoints: RequestHandler = async (request, response) => {
  response.json({
    data: await catalogService.listPoints(branchId(request.params.branchId)),
  });
};

export const listSections: RequestHandler = async (request, response) => {
  response.json({
    data: await catalogService.listSections(branchId(request.params.branchId)),
  });
};

export const listCategories: RequestHandler = async (_request, response) => {
  response.json({ data: await catalogService.listCategories() });
};

export const listProducts: RequestHandler = async (request, response) => {
  response.json({
    data: await catalogService.listProducts(
      branchId(request.params.branchId),
      catalogService.parseProductFilters(request.query),
    ),
  });
};

export const getProduct: RequestHandler = async (request, response) => {
  response.json({
    data: await catalogService.getProduct(
      branchId(request.params.branchId),
      catalogService.parseId(request.params.productId, 'productId'),
    ),
  });
};
