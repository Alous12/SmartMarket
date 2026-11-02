import { Router } from 'express';

import {
  getBranch,
  getProduct,
  listBranches,
  listCategories,
  listPoints,
  listProducts,
  listSections,
} from '../controllers/catalog-controller.js';
import { requireAuth } from '../middlewares/require-auth.js';

export const catalogRouter = Router();

catalogRouter.get('/categories', requireAuth, listCategories);
catalogRouter.get('/branches', requireAuth, listBranches);
catalogRouter.get('/branches/:branchId', requireAuth, getBranch);
catalogRouter.get('/branches/:branchId/points', requireAuth, listPoints);
catalogRouter.get('/branches/:branchId/sections', requireAuth, listSections);
catalogRouter.get('/branches/:branchId/products', requireAuth, listProducts);
catalogRouter.get(
  '/branches/:branchId/products/:productId',
  requireAuth,
  getProduct,
);
