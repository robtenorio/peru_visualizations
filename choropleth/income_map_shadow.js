let w = 700;
let h = 300;

let projection = d3.geoAzimuthalEquidistant()
                   .scale([700])
                   .translate([1100, 0]);
                   //.center([-74, -9]);

// Compute the bounds of a feature of interest, then derive scale & translate.
//var b = path.bounds(),
 //   s = .95 / Math.max((b[1][0] - b[0][0]) / w, (b[1][1] - b[0][1]) / h),
 //   t = [(w - s * (b[1][0] + b[0][0])) / 2, (h - s * (b[1][1] + b[0][1])) / 2];

// Update the projection to use computed scale & translate.
//projection
//    .scale(s)
//    .translate(t);

let color = d3.scaleQuantize()
              .range(["rgb(237, 248, 233)", "rgb(186, 228, 179)", "rgb(116, 196, 118)",
              	"rgb(49, 163, 84)", "rgb(0, 109, 44)"]);

let path = d3.geoPath()
             .projection(projection);

let path2 = d3.geoPath()
             .projection(projection);

let svg = d3.select(".one")
            .append("svg")
            .attr("width", w)
            .attr("height", h);

let btnOne = d3.select("#btn-one");
let btnTwo = d3.select("#btn-two");

let filter = svg.append("defs")
                .append("filter")
                .attr("id", "drop-shadow")
                .attr("height", "130%");

filter.append("feGaussianBlur")
      .attr("in", "SourceAlpha")
      .attr("stdDeviation", 5)
      .attr("result", "blur");

filter.append("feOffset")
      .attr("in", "blur")
      .attr("dx", 5)
      .attr("dy", 5)
      .attr("result", "offsetBlur");

let feMerge = filter.append("feMerge");

feMerge.append("feMergeNode")
       .attr("in", "offsetBlur")

feMerge.append("feMergeNode")
       .attr("in", "SourceGraphic");

let gradient = svg.append("svg:defs")
                  .append("svg:linearGradient")
                  .attr("id", "gradient")
                  .attr("x1", "0%")
                  .attr("y1", "0%")
                  .attr("x2", "0%")
                  .attr("y2", "100%")
                  .attr("spreadMethod", "pad");

gradient.append("svg:stop")
        .attr("offset", "0%")
        .attr("stop-color", "white")
        .attr("stop-opacity", 1);

gradient.append("svg:stop")
        .attr("offset", "100%")
        .attr("stop-color", "white")
        .attr("stop-opacity", 1);

let g = svg.append("g");
let g2 = svg.append("g");

d3.csv("income_dept.csv", data => {

	color.domain([
		d3.min(data, d => d.w_income),
		d3.max(data, d => d.w_income)]);

	d3.json("peru_adm1.geojson", json => {

		//merge the income data and the GeoJSON
		//Loop through once for each department in the income data
		for (let i = 0; i < data.length; i++) {

			//Grab department name
			let dataDept = data[i].name;

			let dataValue = parseFloat(data[i].w_income);

			btnOne.on("click", () =>  {
					color.domain([
						d3.min(data, d => d.w_income),
						d3.max(data, d => d.w_income)]);

				dataValue = parseFloat(data[i].w_income);
				console.log("button one clicked");
			});

			btnTwo.on("click", () => {
					color.domain([
						d3.min(data, d => d.w_food),
						d3.max(data, d => d.w_food)]);

				dataValue = parseFloat(data[i].w_food);
				console.log("button two clicked");
			});

			//Grab income data value

			//Find the corresponding deptartment inside the GeoJSON
			for (let j = 0; j < json.features.length; j++) {

				let jsonDept = json.features[j].properties.lower_name;

				if (dataDept == jsonDept) {

					//Copy the data value into the GeoJSON
					json.features[j].properties.value = dataValue;

					break;
				}
			}
		}

		//Bind data and create on path per GeoJSON feature
		g2.selectAll("path")
		   .data(json.features)
		   .enter()
		   .append("path")
		   .attr("class", "tract")
		   .attr("d", path)
		   .style("fill", d => {
		   	//Get data value
		   	let value = d.properties.value;
		   	if (value) {
		   		return color(value);
		   	} else {
		   		return "#ccc";
		   	}
		   })
		   .on("mouseover", d => {

		   	 //Get centroid of the path
		   	 let centroid = path.centroid(d);
		   	 let xPosition = centroid[0];
		   	 let yPosition = centroid[1];
		     //Update the tooltip name
		     d3.select("#tooltip")
		       .style("left", xPosition + "px")
		       .style("top", yPosition + 200 + "px")
		       .select("#name")
		       .text(`Department: ${d.properties.NAME_1} \nValue: ${Math.round(d.properties.value)}`);

             //Show the tooltip
		     d3.select("#tooltip").classed("hidden", false);

			   })
			.on("mouseout", () => {
			//Hide the tooltip
			d3.select("#tooltip").classed("hidden", true);
		    });

		let pe = {
			"decimal": ",",
			"thousands": ".",
			"grouping": [3],
			"currency": ["S/. ", ""]
		};

		//Create the legend
		g2.append("g")
		   .attr("class", "legend")
		   .attr("transform", "translate(350,100)");

		let legend = d3.legendColor()
		               .cells(5)
		               .orient('vertical')
		               .title('Average HH Income')
		               .labelFormat(d3.format("$,.2f"))
		               .locale(pe)
		               .scale(color);

		g2.select(".legend")
		   .call(legend);

		d3.json("peru_adm0.geojson", json => {
			g.selectAll("path")
			 .data(json.features)
			 .enter()
			 .append("path")
			 .attr("class", "adm0")
			 .attr("d", path)
			 .style("filter", "url(#drop-shadow)")
			 .style("fill", "url(#gradient)");

});

	});
});










