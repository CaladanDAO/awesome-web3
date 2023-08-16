{
    "transfer": { frame: {"sender":   { "@type": "address", "name": "x", "state": "balanceOf" },
			  "receiver": { "@type": "address", "name": "y", "state": "balanceOf" },
			  "amount":   { "@type": "xsd:integer", "name": "z" } },
		  asserts: [
		      `diff("x", "balanceOf") = -z`,
		      `diff("y", "balanceOf") = z`
		  ]
		},
    "mint": { frame: {"x": "minter", "z": "amount"},
	      asserts: [
		  `diff("contract_address", "totalSupply") = z`
	      ]
	    }
    "burn": { frame: {"x": "burner", "z": "amount"},
	      asserts: [
		  `diff("contract_address", "totalSupply") = -z`
	      ]}
}
function decorateFungibleAmount(value, ctx) {
    let c = new Contract(ctx.contract_address);
    let priceUSD = c.lookup("priceUSD");
    let decimals = c.call('decimals');
    return {
	tokenAddress: ctx.contract_address,
	value_float: value / (10 ** decimals),
  	symbol: c.call('symbol'),
	decimals,
	valueUSD: priceUSD && value_float ? priceUSD * value_float : null
    }
}
