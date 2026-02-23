@mod inventory_system
"A warehouse inventory management system that tracks stock levels and prevents overselling"

@type StockLevel = { qty : Int | qty >= 0 }
@invariant qty >= 0

@type Product = { sku : Str , name : Str , stock : StockLevel , price : Money }

@fn restock ( sku : Str , amount : Int ) -> Result<Product>
  "Add inventory to an existing product"
  @req amount > 0
  @ens stock' >= stock
  @effect Mutation
  "Find the product by SKU and increase its stock level"
  "Log the restock event for audit purposes"
  @effect IO

@fn sell ( sku : Str , quantity : Int ) -> Result<Product>
  "Decrease stock when a sale is made"
  @req quantity > 0
  @ens stock' >= 0
  @effect Mutation
  @effect IO
  "Verify sufficient stock exists before committing the sale"
  !! "Never allow stock to go negative — reject the sale instead"

@fn transfer ( from_sku : Str , to_sku : Str , quantity : Int ) -> Result<()>
  "Move stock between two products in the warehouse"
  @req quantity > 0
  @ens "Total inventory across both SKUs remains unchanged"
  @effect Mutation
  @effect IO
  @decreases quantity
  "Deduct from source, add to destination"
  "If source has insufficient stock, transfer what is available"

@fn audit_stock -> List<Product>
  "Generate a full inventory report"
  @pure
  @ens "Every product in the result has stock >= 0"
  "Iterate all products and collect current stock levels"
  "Sort by SKU for consistent ordering"
