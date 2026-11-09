-- Reference only. Already included in olist_mysql.sql.
CREATE TABLE `customers` (
  `customer_id` CHAR(32) NOT NULL,
  `customer_unique_id` CHAR(32),
  `customer_zip_code_prefix` VARCHAR(5),
  `customer_city` VARCHAR(255),
  `customer_state` CHAR(2),
  PRIMARY KEY (`customer_id`),
  KEY idx_customer_unique (`customer_unique_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `products` (
  `product_id` CHAR(32) NOT NULL,
  `product_category_name` VARCHAR(255),
  `product_name_lenght` INT,
  `product_description_lenght` INT,
  `product_photos_qty` INT,
  `product_weight_g` INT,
  `product_length_cm` INT,
  `product_height_cm` INT,
  `product_width_cm` INT,
  PRIMARY KEY (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `category_translation` (
  `product_category_name` VARCHAR(255) NOT NULL,
  `product_category_name_english` VARCHAR(255),
  PRIMARY KEY (`product_category_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `orders` (
  `order_id` CHAR(32) NOT NULL,
  `customer_id` CHAR(32),
  `order_status` VARCHAR(255),
  `order_purchase_timestamp` DATETIME,
  `order_approved_at` DATETIME,
  `order_delivered_carrier_date` DATETIME,
  `order_delivered_customer_date` DATETIME,
  `order_estimated_delivery_date` DATETIME,
  PRIMARY KEY (`order_id`),
  FOREIGN KEY (`customer_id`) REFERENCES `customers` (`customer_id`),
  KEY idx_purchase (`order_purchase_timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `order_items` (
  `order_id` CHAR(32) NOT NULL,
  `order_item_id` INT NOT NULL,
  `product_id` CHAR(32),
  `seller_id` CHAR(32),
  `shipping_limit_date` DATETIME,
  `price` DECIMAL(12,2),
  `freight_value` DECIMAL(12,2),
  PRIMARY KEY (`order_id`,`order_item_id`),
  FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`),
  FOREIGN KEY (`product_id`) REFERENCES `products` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;