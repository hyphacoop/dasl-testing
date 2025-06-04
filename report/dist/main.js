// Main filtering function
function filterTableRows() {
  const dropdown = document.getElementById("tagFilter");
  const selectedValue = dropdown.value;

  // Get all tables on the page
  const tables = document.querySelectorAll("table");

  tables.forEach((table) => {
    // Get all tbody rows in this table
    const rows = table.querySelectorAll("tbody tr");
    let visibleRowCount = 0;

    rows.forEach((row) => {
      if (selectedValue === "all") {
        // Show all rows
        row.classList.remove("hidden");
        visibleRowCount++;
      } else {
        // Hide row if it doesn't have the selected class
        if (row.classList.contains(selectedValue)) {
          row.classList.remove("hidden");
          visibleRowCount++;
        } else {
          row.classList.add("hidden");
        }
      }
    });

    // Hide the entire table if no rows are visible
    if (visibleRowCount === 0) {
      table.parentElement.classList.add("hidden");
    } else {
      table.parentElement.classList.remove("hidden");
    }
  });
}

function testGrouping() {
  const dropdown = document.getElementById("grouping");
  const selectedValue = dropdown.value;

  // Reset tag filtering also
  document.getElementById("tagFilter").value = "all";
  filterTableRows();

  document.querySelectorAll(".test-group-group").forEach((elem) => {
    elem.style.display = "none";
  });
  document.getElementById(selectedValue).style.display = "block";

  if (selectedValue == "tests-by-tag") {
    // Hide tag filtering when tests are already grouped by tag
    document.getElementById("tagFilter-container").style.display = "none";
  } else {
    document.getElementById("tagFilter-container").style.display = "block";
  }
}

// Modal functions
function showModal(obj) {
  const modal = document.getElementById("modal");
  const modalText = document.getElementById("modal-text");
  modalText.textContent = JSON.stringify(obj, null, 2);
  modal.style.display = "block";
  document.body.style.overflow = "hidden";
}

function closeModal() {
  const modal = document.getElementById("modal");
  modal.style.display = "none";
  document.body.style.overflow = "";
}

// Charts
function displayCharts() {
  const charts = document.querySelectorAll(".chart-container");
  charts.forEach((chart) => {
    var myChart = echarts.init(chart);
    var option;

    option = {
      tooltip: {
        trigger: "item",
      },
      title: {
        text: chart.dataset.lib,
        textStyle: {
          color: "#c2c7d0",
        },
      },
      series: [
        {
          type: "pie",
          radius: ["40%", "70%"],
          avoidLabelOverlap: false,
          label: {
            show: false,
            position: "center",
          },
          emphasis: {
            label: {
              show: false,
              fontSize: 40,
              fontWeight: "bold",
            },
          },
          labelLine: {
            show: false,
          },
          data: [
            { value: Number(chart.dataset.pass), name: "Pass" },
            { value: Number(chart.dataset.fail), name: "Fail" },
          ],
          color: ["#398712", "#D93526"],
        },
      ],
    };

    option && myChart.setOption(option);
    window.addEventListener("resize", myChart.resize);
  });
}

// Set up event listener when page loads
document.addEventListener("DOMContentLoaded", function () {
  displayCharts();

  document
    .getElementById("tagFilter")
    .addEventListener("change", filterTableRows);
  document.getElementById("grouping").addEventListener("change", testGrouping);

  // Set up grouping for the first time also
  testGrouping();

  // Close modal when clicking outside of it
  const modal = document.getElementById("modal");
  window.addEventListener("click", function (event) {
    if (event.target === modal) {
      closeModal();
    }
  });
});
