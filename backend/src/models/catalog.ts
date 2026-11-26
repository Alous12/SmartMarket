export type BranchPointType = 'ENTRANCE' | 'CHECKOUT' | 'OTHER';

export interface Branch {
  branch_id: number;
  name: string;
  address: string;
  latitude: number;
  longitude: number;
  status: boolean;
  model_3d_url: string | null;
}

export interface BranchPoint {
  point_id: number;
  branch_id: number;
  name: string;
  point_type: BranchPointType;
  coordinate_x: number;
  coordinate_y: number;
  coordinate_z: number;
}

export interface Section {
  section_id: number;
  branch_id: number;
  name: string;
  description: string | null;
}

export interface Category {
  category_id: number;
  name: string;
  description: string | null;
}

export interface ProductLocation {
  product_location_id: number;
  section_id: number;
  section_name: string;
  coordinate_x: number;
  coordinate_y: number;
  coordinate_z: number;
  shelf: string | null;
}

export interface BranchProduct {
  product_id: number;
  sku: string;
  name: string;
  brand: string | null;
  price: number;
  unit_of_measure: string;
  image_url: string | null;
  category_id: number;
  category_name: string;
  stock_quantity: number;
  locations: ProductLocation[];
}

export interface ProductFilters {
  search?: string;
  categoryId?: number;
  productIds?: number[];
}

export type AdminInventoryOperation = 'list' | 'count' | 'stock' | 'value';
export type AdminInventoryStockFilter = 'all' | 'low' | 'out';
export type AdminInventorySort =
  | 'name'
  | 'stock_asc'
  | 'stock_desc'
  | 'price_asc'
  | 'price_desc'
  | 'value_desc';

export interface AdminInventoryQuery {
  operation: AdminInventoryOperation;
  searchTerms: string[];
  category: string | null;
  stock: AdminInventoryStockFilter;
  sort: AdminInventorySort;
  limit: number;
  groupByCategory: boolean;
  includeLocations: boolean;
}

export interface AdminInventoryProduct {
  name: string;
  sku: string;
  brand: string | null;
  category: string;
  price: number;
  unit: string;
  stock: number;
  locations: Array<{ section: string; shelf: string | null }>;
}

export interface AdminInventoryCategorySummary {
  category: string;
  products: number;
  stock: number;
  value: number;
}

export interface AdminInventoryResult {
  summary: {
    products: number;
    stock: number;
    value: number;
    lowStockProducts: number;
    outOfStockProducts: number;
  };
  products: AdminInventoryProduct[];
  categories: AdminInventoryCategorySummary[];
}
