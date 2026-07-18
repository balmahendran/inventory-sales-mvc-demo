
-- Inventory & Sales Management Mini-System

CREATE DATABASE InventorySalesDemo;
GO
USE InventorySalesDemo;
GO



CREATE TABLE Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductName NVARCHAR(100) NOT NULL,
    SKU NVARCHAR(50) NOT NULL UNIQUE,
    UnitPrice DECIMAL(10,2) NOT NULL,
    StockQuantity INT NOT NULL DEFAULT 0,
    ReorderThreshold INT NOT NULL DEFAULT 10,
    CreatedDate DATETIME DEFAULT GETDATE()
);

CREATE TABLE Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerName NVARCHAR(100) NOT NULL,
    Email NVARCHAR(100),
    Phone NVARCHAR(20),
    CreatedDate DATETIME DEFAULT GETDATE()
);

CREATE TABLE Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATETIME DEFAULT GETDATE(),
    TotalAmount DECIMAL(10,2) NOT NULL DEFAULT 0,
    Status NVARCHAR(20) DEFAULT 'Completed',
    FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

CREATE TABLE OrderItems (
    OrderItemID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(10,2) NOT NULL,
    LineTotal AS (Quantity * UnitPrice) PERSISTED,
    FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);
GO

    
-- STORED PROCEDURE 

CREATE PROCEDURE sp_CreateOrder
    @CustomerID INT,
    @ProductID INT,
    @Quantity INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @UnitPrice DECIMAL(10,2);
        DECLARE @AvailableStock INT;
        DECLARE @OrderID INT;

        SELECT @UnitPrice = UnitPrice, @AvailableStock = StockQuantity
        FROM Products WHERE ProductID = @ProductID;

        IF @AvailableStock < @Quantity
        BEGIN
            RAISERROR('Insufficient stock for this product.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END

        INSERT INTO Orders (CustomerID, TotalAmount)
        VALUES (@CustomerID, 0);

        SET @OrderID = SCOPE_IDENTITY();

        INSERT INTO OrderItems (OrderID, ProductID, Quantity, UnitPrice)
        VALUES (@OrderID, @ProductID, @Quantity, @UnitPrice);

        UPDATE Products
        SET StockQuantity = StockQuantity - @Quantity
        WHERE ProductID = @ProductID;

        UPDATE Orders
        SET TotalAmount = @Quantity * @UnitPrice
        WHERE OrderID = @OrderID;

        COMMIT TRANSACTION;

        SELECT @OrderID AS NewOrderID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO



CREATE PROCEDURE sp_GetLowStockItems
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ProductID,
        ProductName,
        SKU,
        StockQuantity,
        ReorderThreshold,
        (ReorderThreshold - StockQuantity) AS UnitsBelowThreshold
    FROM Products
    WHERE StockQuantity <= ReorderThreshold
    ORDER BY UnitsBelowThreshold DESC;
END
GO



CREATE PROCEDURE sp_GetTopSellingProducts
    @TopN INT = 5
AS
BEGIN
    SET NOCOUNT ON;
    SELECT TOP (@TopN)
        p.ProductID,
        p.ProductName,
        SUM(oi.Quantity) AS TotalUnitsSold,
        SUM(oi.LineTotal) AS TotalRevenue
    FROM OrderItems oi
    JOIN Products p ON oi.ProductID = p.ProductID
    GROUP BY p.ProductID, p.ProductName
    ORDER BY TotalUnitsSold DESC;
END
GO



INSERT INTO Products (ProductName, SKU, UnitPrice, StockQuantity, ReorderThreshold)
VALUES
('Wireless Mouse', 'WM-001', 25.00, 50, 15),
('USB-C Cable', 'UC-002', 10.00, 8, 20),
('Laptop Stand', 'LS-003', 45.00, 5, 10),
('Mechanical Keyboard', 'MK-004', 85.00, 30, 10),
('Monitor 24"', 'MN-005', 350.00, 3, 5);

INSERT INTO Customers (CustomerName, Email, Phone)
VALUES
('Ahmed Al Mansouri', 'ahmed@example.com', '0501234567'),
('Fatima Noor', 'fatima@example.com', '0559876543');


EXEC sp_CreateOrder @CustomerID = 1, @ProductID = 1, @Quantity = 5;
EXEC sp_GetLowStockItems;
EXEC sp_GetTopSellingProducts @TopN = 5;
