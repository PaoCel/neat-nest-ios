import Foundation

enum SeededProductCatalog {
    static let items: [ProductCatalogItem] = [
        ProductCatalogItem(
            id: "latte-arborea",
            canonicalName: "Latte Arborea",
            brand: "Arborea",
            category: "Freschi",
            subcategory: "Latte",
            sizeLabel: "1 L",
            aliases: [
                "latte arborea",
                "arborea latte",
                "latte intero arborea"
            ],
            searchableTokens: [
                "latte",
                "arborea",
                "latticini",
                "frigo"
            ],
            barcode: nil,
            isActive: true
        ),
        ProductCatalogItem(
            id: "latte-senza-lattosio",
            canonicalName: "Latte senza lattosio",
            brand: nil,
            category: "Freschi",
            subcategory: "Latte",
            sizeLabel: "1 L",
            aliases: [
                "latte delattosato",
                "latte lactose free",
                "mezzo litro di latte senza lattosio",
                "latte senza lattosio"
            ],
            searchableTokens: [
                "latte",
                "senza",
                "lattosio",
                "delattosato"
            ],
            barcode: nil,
            isActive: true
        ),
        ProductCatalogItem(
            id: "tonno-allolio",
            canonicalName: "Tonno all'olio",
            brand: nil,
            category: "Dispensa",
            subcategory: "Conserve",
            sizeLabel: "3 x 80 g",
            aliases: [
                "tonno all olio",
                "tonno all'olio",
                "tonno in scatola",
                "tonno olio"
            ],
            searchableTokens: [
                "tonno",
                "olio",
                "dispensa",
                "scatola"
            ],
            barcode: nil,
            isActive: true
        ),
        ProductCatalogItem(
            id: "zucchine",
            canonicalName: "Zucchine",
            brand: nil,
            category: "Ortofrutta",
            subcategory: "Verdure",
            sizeLabel: "500 g",
            aliases: [
                "zucchina",
                "zucchine fresche"
            ],
            searchableTokens: [
                "zucchine",
                "verdure",
                "orto"
            ],
            barcode: nil,
            isActive: true
        ),
        ProductCatalogItem(
            id: "pasta-barilla",
            canonicalName: "Pasta Barilla",
            brand: "Barilla",
            category: "Dispensa",
            subcategory: "Pasta",
            sizeLabel: "500 g",
            aliases: [
                "barilla pasta",
                "pasta di semola barilla",
                "pasta barilla"
            ],
            searchableTokens: [
                "pasta",
                "barilla",
                "dispensa",
                "spaghetti"
            ],
            barcode: nil,
            isActive: true
        ),
        ProductCatalogItem(
            id: "pane",
            canonicalName: "Pane",
            brand: nil,
            category: "Panetteria",
            subcategory: "Pane",
            sizeLabel: "1 filone",
            aliases: [
                "pane fresco",
                "filone di pane",
                "pagnotta"
            ],
            searchableTokens: [
                "pane",
                "panetteria",
                "forno"
            ],
            barcode: nil,
            isActive: true
        ),
        ProductCatalogItem(
            id: "uova",
            canonicalName: "Uova",
            brand: nil,
            category: "Freschi",
            subcategory: "Uova",
            sizeLabel: "6 pz",
            aliases: [
                "uova fresche",
                "uova medie",
                "uova grandi"
            ],
            searchableTokens: [
                "uova",
                "colazione",
                "frigo"
            ],
            barcode: nil,
            isActive: true
        ),
        ProductCatalogItem(
            id: "yogurt-greco",
            canonicalName: "Yogurt greco",
            brand: nil,
            category: "Freschi",
            subcategory: "Yogurt",
            sizeLabel: "170 g",
            aliases: [
                "yogurt greco bianco",
                "greek yogurt",
                "yogurt greco"
            ],
            searchableTokens: [
                "yogurt",
                "greco",
                "frigo"
            ],
            barcode: nil,
            isActive: true
        ),
        ProductCatalogItem(
            id: "petto-di-pollo",
            canonicalName: "Petto di pollo",
            brand: nil,
            category: "Macelleria",
            subcategory: "Pollo",
            sizeLabel: "400 g",
            aliases: [
                "petto pollo",
                "petto di pollo a fette",
                "pollo"
            ],
            searchableTokens: [
                "petto",
                "pollo",
                "proteine",
                "carne"
            ],
            barcode: nil,
            isActive: true
        ),
        ProductCatalogItem(
            id: "riso-basmati",
            canonicalName: "Riso basmati",
            brand: nil,
            category: "Dispensa",
            subcategory: "Riso",
            sizeLabel: "1 kg",
            aliases: [
                "basmati",
                "riso basmati",
                "riso lungo"
            ],
            searchableTokens: [
                "riso",
                "basmati",
                "dispensa",
                "cereali"
            ],
            barcode: nil,
            isActive: true
        )
    ]
}
